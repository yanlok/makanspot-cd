/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// enrich-scraped-posts
// ----------------------------------------------------------------------------
// Reads pending rows from public.scraped_posts, extracts a structured venue
// from each caption (LLM), geocodes it (Google), then promotes qualifying rows
// into public.restaurants with is_approved = false for admin review.
//
// Note: Google Places API has been removed from this pipeline due to cost.
// Only Geocoding API is used (free tier covers ~42K requests/month).
// Phone/rating/hours from Places are no longer populated.
//
// Row outcomes (status column):
//   promoted -> a restaurant row was created (or matched an existing one)
//   skipped  -> the LLM decided it is not a single identifiable restaurant
//   failed   -> not enough info to satisfy NOT NULL columns (needs admin)
//
// POST body (all optional): { limit?: number, minConfidence?: number }
// Response: { processed, promoted, skipped, failed }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  deriveCategories,
  extractVenue,
  geocode,
  isHiddenGem,
  popularityScore,
  type VenueExtraction,
} from "../_shared/enrich.ts";

interface StagedRow {
  id: number;
  platform: string;
  web_video_url: string;
  author_name: string | null;
  caption: string | null;
  cover_url: string | null;
  hashtags: string[] | null;
  digg_count: number;
  play_count: number;
  share_count: number;
  extraction: VenueExtraction | null;
}

/** An existing restaurant considered as a merge candidate. */
interface RestaurantRow {
  id: number;
  name: string;
  latitude: number | null;
  longitude: number | null;
  popularity_score: number | null;
  is_trending: boolean | null;
  is_hidden_gem: boolean | null;
  source_post_count: number | null;
  top_play_count: number | null;
}

/** Lowercase, strip punctuation/accents, collapse whitespace. */
function normalizeName(name: string | null): string {
  return (name ?? "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

/**
 * Name relationship between two already-normalized venue names:
 *   "equal"  -> identical
 *   "prefix" -> one is a prefix of the other (>= 5 chars), e.g.
 *               "village park" vs "village park restaurant"
 *   "none"   -> unrelated
 * Prefix (not arbitrary substring) keeps distinct "nasi lemak X" places apart.
 */
function nameRelation(a: string, b: string): "equal" | "prefix" | "none" {
  if (!a || !b) return "none";
  if (a === b) return "equal";
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  if (short.length >= 5 && long.startsWith(short)) return "prefix";
  return "none";
}

/** Upsert each category by name and link it to the restaurant (idempotent). */
async function linkCategories(
  supabase: SupabaseClient,
  restaurantId: number,
  categories: string[],
): Promise<void> {
  for (const name of [...new Set(categories)]) {
    if (!name) continue;
    const { data: cat } = await supabase
      .from("categories")
      .upsert({ name }, { onConflict: "name" })
      .select("id")
      .single();
    if (cat?.id != null) {
      await supabase.from("restaurant_categories").upsert(
        { restaurant_id: restaurantId, category_id: cat.id },
        { onConflict: "restaurant_id,category_id", ignoreDuplicates: true },
      );
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const body = await req.json().catch(() => ({}));
  const limit = Math.min(Number(body?.limit ?? 25), 100);
  const minConfidence = Number(body?.minConfidence ?? 0.5);

  // Diagnostic mode: report status counts + recent failures. Also resets
  // failed rows back to pending when { action: "status", reset: true }.
  if (body?.action === "status") {
    if (body?.reset === true) {
      await supabase.from("scraped_posts")
        .update({ status: "pending", error: null, processed_at: null })
        .eq("status", "failed");
    }
    const { data: rows } = await supabase
      .from("scraped_posts")
      .select("id, status, error, extraction_confidence, extraction")
      .in("status", ["failed", "skipped", "promoted"])
      .order("processed_at", { ascending: false })
      .limit(15);
    const counts: Record<string, number> = {};
    for (const s of ["pending", "promoted", "skipped", "failed"]) {
      const { count } = await supabase
        .from("scraped_posts").select("id", { count: "exact", head: true })
        .eq("status", s);
      counts[s] = count ?? 0;
    }
    return jsonResponse({
      counts,
      recent: (rows ?? []).map((r: {
        id: number;
        status: string;
        error: string | null;
        extraction_confidence: number | null;
        extraction: unknown;
      }) => ({
        id: r.id,
        status: r.status,
        error: r.error,
        confidence: r.extraction_confidence,
        name: (r.extraction as { name?: string } | null)?.name ?? null,
      })),
    });
  }

  // Reprocess mode: delete restaurants previously promoted from scraped posts
  // and reset those rows to pending so the current merge logic can rebuild them
  // cleanly. Skipped (non-venue) rows are left untouched. The stored `extraction`
  // is reused on the next run, so this costs no LLM tokens.
  if (body?.action === "reprocess") {
    const { data: promotedRows } = await supabase
      .from("scraped_posts")
      .select("promoted_restaurant_id")
      .not("promoted_restaurant_id", "is", null);
    const ids = [
      ...new Set(
        (promotedRows ?? [])
          .map((r: { promoted_restaurant_id: number | null }) =>
            r.promoted_restaurant_id
          )
          .filter((v: number | null): v is number => v != null),
      ),
    ];
    if (ids.length) {
      await supabase.from("restaurants").delete().in("id", ids);
    }
    const { count } = await supabase
      .from("scraped_posts")
      .update({
        status: "pending",
        promoted_restaurant_id: null,
        error: null,
        processed_at: null,
      }, { count: "exact" })
      .in("status", ["promoted", "failed"]);
    return jsonResponse({
      reset_to_pending: count ?? 0,
      deleted_restaurants: ids.length,
    });
  }

  // Claim a batch of pending rows.
  const { data: pending, error: fetchErr } = await supabase
    .from("scraped_posts")
    .select(
      "id, platform, web_video_url, author_name, caption, cover_url, hashtags, digg_count, play_count, share_count, extraction",
    )
    .eq("status", "pending")
    .order("id", { ascending: true })
    .limit(limit);

  if (fetchErr) return jsonResponse({ error: fetchErr.message }, 500);
  if (!pending || pending.length === 0) {
    return jsonResponse({ processed: 0, promoted: 0, skipped: 0, failed: 0 });
  }

  let promoted = 0, merged = 0, skipped = 0, failed = 0;

  for (const row of pending as StagedRow[]) {
    const hashtags = row.hashtags ?? [];
    const caption = row.caption ?? "";

    const finish = (
      status: "promoted" | "skipped" | "failed",
      patch: Record<string, unknown> = {},
    ) =>
      supabase.from("scraped_posts").update({
        status,
        processed_at: new Date().toISOString(),
        ...patch,
      }).eq("id", row.id);

    try {
      // Reuse a previously stored extraction when present (e.g. after a
      // reprocess) so re-runs cost no LLM tokens; otherwise call the LLM.
      const venue: VenueExtraction =
        row.extraction && typeof row.extraction === "object" &&
          "is_restaurant" in row.extraction
          ? row.extraction
          : await extractVenue(caption, hashtags, row.author_name);

      // Not a single identifiable eatery -> skip (e.g. generic listicles).
      if (!venue.is_restaurant || !venue.name) {
        skipped++;
        await finish("skipped", { extraction: venue, extraction_confidence: venue.confidence });
        continue;
      }

      const geo = await geocode(venue.name, venue.address, venue.city);

      // restaurants requires NOT NULL name/address/lat/long. Without coordinates
      // or above the confidence bar we cannot auto-promote -> leave for admin.
      if (!geo || venue.confidence < minConfidence) {
        failed++;
        await finish("failed", {
          extraction: venue,
          extraction_confidence: venue.confidence,
          error: !geo ? "geocoding_failed" : "low_confidence",
        });
        continue;
      }

      const address = geo.formatted_address ?? venue.address ?? venue.city ?? "Malaysia";
      const thisScore = popularityScore(row.play_count, row.digg_count, row.share_count);
      const thisTrending = row.play_count >= 50000;
      const thisGem = isHiddenGem(hashtags, caption);

      // Categories: use the LLM's taxonomy pick, else derive from cuisine/name/
      // hashtags. "Hidden Gem" is added as a filterable category when detected.
      const cats = venue.categories?.length
        ? [...venue.categories]
        : deriveCategories(venue.cuisine, venue.name, hashtags);
      if (thisGem && !cats.includes("Hidden Gem")) cats.push("Hidden Gem");

      // Find an existing restaurant for the SAME real-world venue. Query a wide
      // candidate window (~13km) then decide per-candidate:
      //   exact name  -> merge anywhere in the window (same-name geocodes drift)
      //   prefix name -> merge only if very close (~450m), to stay conservative
      const box = 0.12;
      const { data: nearby } = await supabase
        .from("restaurants")
        .select(
          "id, name, latitude, longitude, popularity_score, is_trending, is_hidden_gem, source_post_count, top_play_count",
        )
        .gte("latitude", geo.latitude - box)
        .lte("latitude", geo.latitude + box)
        .gte("longitude", geo.longitude - box)
        .lte("longitude", geo.longitude + box);

      const normName = normalizeName(venue.name);
      const match = (nearby as RestaurantRow[] | null ?? []).find((c) => {
        const rel = nameRelation(normName, normalizeName(c.name));
        if (rel === "none") return false;
        if (rel === "equal") return true;
        const dLat = Math.abs((c.latitude ?? 0) - geo.latitude);
        const dLng = Math.abs((c.longitude ?? 0) - geo.longitude);
        return dLat <= 0.004 && dLng <= 0.004; // prefix match must be nearby
      });

      if (match) {
        // Merge: aggregate engagement and keep the highest-play video as primary.
        const isNewTop = row.play_count > (match.top_play_count ?? 0);
        const patch: Record<string, unknown> = {
          popularity_score: (match.popularity_score ?? 0) + thisScore,
          is_trending: (match.is_trending ?? false) || thisTrending,
          is_hidden_gem: (match.is_hidden_gem ?? false) || thisGem,
          source_post_count: (match.source_post_count ?? 0) + 1,
          last_updated: new Date().toISOString(),
        };
        if (isNewTop) {
          patch.top_play_count = row.play_count;
          patch.post_url = row.web_video_url;
          patch.social_media_source = row.platform;
          if (venue.description) patch.description = venue.description;
        }
        const { error: updErr } = await supabase
          .from("restaurants").update(patch).eq("id", match.id);
        if (updErr) {
          failed++;
          await finish("failed", {
            extraction: venue,
            extraction_confidence: venue.confidence,
            error: updErr.message,
          });
          continue;
        }
        await linkCategories(supabase, match.id, cats);
        merged++;
        await finish("promoted", {
          extraction: venue,
          extraction_confidence: venue.confidence,
          promoted_restaurant_id: match.id,
        });
        continue;
      }

      // No match -> insert a new restaurant (pending approval for admin review).
      const { data: inserted, error: insErr } = await supabase
        .from("restaurants")
        .insert({
          name: venue.name,
          description: venue.description,
          address,
          latitude: geo.latitude,
          longitude: geo.longitude,
          price_range: venue.price_range ?? "$$",
          social_media_source: row.platform,
          post_url: row.web_video_url,
          popularity_score: thisScore,
          top_play_count: row.play_count,
          source_post_count: 1,
          is_hidden_gem: thisGem,
          is_trending: thisTrending,
          is_approved: false,
        })
        .select("id")
        .single();

      if (insErr || !inserted) {
        failed++;
        await finish("failed", {
          extraction: venue,
          extraction_confidence: venue.confidence,
          error: insErr?.message ?? "insert_failed",
        });
        continue;
      }
      await linkCategories(supabase, inserted.id, cats);

      promoted++;
      await finish("promoted", {
        extraction: venue,
        extraction_confidence: venue.confidence,
        promoted_restaurant_id: inserted.id,
      });
    } catch (e) {
      failed++;
      await finish("failed", { error: String(e) });
    }
  }

  return jsonResponse({ processed: pending.length, promoted, merged, skipped, failed });
});
