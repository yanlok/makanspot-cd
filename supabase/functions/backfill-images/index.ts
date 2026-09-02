/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// backfill-images
// ----------------------------------------------------------------------------
// One-shot endpoint that re-applies the image fallback chain to a list of
// restaurant IDs. Used to recover restaurants that ended up with a
// placeholder (or no) primary image even though their linked posts carry a
// usable cover photo — e.g. images the older, stricter validator rejected.
//
// POST body: { restaurant_ids: number[] }
// Response:  { results: Array<{ restaurant_id, source, image_url, error? }> }
//
// Uses the shared enrich helpers so the chain here stays identical to the
// pipeline's: rehost to our storage, LLM validation, placeholder fallback.
// An earlier self-contained copy diverged from the pipeline (it re-persisted
// whatever row already existed and stored ephemeral Instagram CDN URLs),
// which made real repairs impossible.
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  persistRestaurantImageChain,
  selectBestImageCandidate,
} from "../_shared/enrich.ts";
type DbClient = SupabaseClient<any, any, any, any, any>;

// ---------------------------------------------------------------------------
// Inlined from _shared/cors.ts
// ---------------------------------------------------------------------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Inlined from _shared/http.ts
// ---------------------------------------------------------------------------
async function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit = {},
  timeoutMs = 15_000,
): Promise<Response> {
  const timeout = AbortSignal.timeout(Math.max(1, timeoutMs));
  const signal = init.signal
    ? AbortSignal.any([init.signal, timeout])
    : timeout;
  return await fetch(input, { ...init, signal });
}

// ---------------------------------------------------------------------------
// Inlined from _shared/auth.ts
// ---------------------------------------------------------------------------
function bearerToken(req: Request): string | null {
  const value = req.headers.get("Authorization") ?? "";
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}
async function sha256(value: string): Promise<Uint8Array> {
  const bytes = new TextEncoder().encode(value);
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}
async function isServiceRoleRequest(req: Request): Promise<boolean> {
  const token = bearerToken(req) ?? "";
  const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!token || !expected) return false;
  const [a, b] = await Promise.all([sha256(token), sha256(expected)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  if (diff === 0) return true;
  try {
    const seg = token.split(".")[1];
    if (!seg) return false;
    const base64 = seg.replace(/-/g, "+").replace(/_/g, "/")
      .padEnd(Math.ceil(seg.length / 4), "=");
    const payload = JSON.parse(atob(base64)) as { role?: string };
    return payload.role === "service_role";
  } catch {
    return false;
  }
}
async function isAdminRequest(
  req: Request,
  supabase: SupabaseClient,
): Promise<boolean> {
  if (await isServiceRoleRequest(req)) return true;
  const token = bearerToken(req);
  if (!token) return false;
  const seg = token.split(".")[1];
  if (!seg) return false;
  let userId: string | null = null;
  try {
    const base64 = seg.replace(/-/g, "+").replace(/_/g, "/")
      .padEnd(Math.ceil(seg.length / 4), "=");
    const payload = JSON.parse(atob(base64)) as {
      sub?: string;
      role?: string;
    };
    if (payload.role === "service_role") return true;
    userId = payload.sub ?? null;
  } catch {
    return false;
  }
  if (!userId) return false;
  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  return !profileError && profile?.role === "admin";
}

// ---------------------------------------------------------------------------
// Backfill-specific helpers
// ---------------------------------------------------------------------------
interface BackfillRequest {
  restaurant_ids: number[];
}
interface BackfillResult {
  restaurant_id: number;
  name: string | null;
  source: string | null;
  image_url: string | null;
  error: string | null;
}

async function fetchOwnerProfilePicForRestaurant(
  supabase: DbClient,
  restaurantId: number,
): Promise<string | null> {
  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) return null;
  // Find the most recent post linked to this restaurant.
  const { data: linkRows, error: linkErr } = await supabase
    .from("restaurant_social_posts")
    .select("post_id")
    .eq("restaurant_id", restaurantId)
    .order("post_id", { ascending: false })
    .limit(1);
  if (linkErr || !linkRows || linkRows.length === 0) return null;
  const postId = linkRows[0].post_id;
  const { data: postRow, error: postErr } = await supabase
    .from("scraped_posts")
    .select("post_url, author_username")
    .eq("id", postId)
    .maybeSingle();
  if (postErr || !postRow?.post_url) return null;
  // Call the Apify instagram-scraper on the single post URL with
  // addParentData: true.  This costs ~$0.006 per post and gives us the
  // owner profile pic in a single round-trip.  Only worth it when tier 1
  // has no candidate at all.
  try {
    const startResp = await fetchWithTimeout(
      "https://api.apify.com/v2/acts/apify%2Finstagram-scraper/runs",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          directUrls: [postRow.post_url],
          resultsType: "posts",
          resultsLimit: 1,
          addParentData: true,
        }),
      },
      15_000,
    );
    if (!startResp.ok) {
      console.warn(
        `[backfill] Apify start failed (${startResp.status})`,
      );
      return null;
    }
    const startJson = await startResp.json() as {
      data: { id: string; defaultDatasetId: string };
    };
    const runId = startJson?.data?.id;
    const datasetId = startJson?.data?.defaultDatasetId;
    if (!runId || !datasetId) return null;
    // Poll for completion (up to 30 s).
    for (let i = 0; i < 6; i++) {
      await new Promise((r) => setTimeout(r, 5000));
      const statusResp = await fetchWithTimeout(
        `https://api.apify.com/v2/acts/apify%2Finstagram-scraper/runs/${runId}`,
        { headers: { Authorization: `Bearer ${token}` } },
        8_000,
      );
      if (!statusResp.ok) continue;
      const status = await statusResp.json() as {
        data: { status: string };
      };
      if (status.data.status !== "SUCCEEDED") continue;
      const itemsResp = await fetchWithTimeout(
        `https://api.apify.com/v2/datasets/${datasetId}/items?format=json&limit=1`,
        { headers: { Authorization: `Bearer ${token}` } },
        8_000,
      );
      if (!itemsResp.ok) return null;
      const items = await itemsResp.json() as Array<Record<string, unknown>>;
      for (const item of items) {
        const parent = (item.parentData ?? {}) as Record<string, unknown>;
        const owner = (parent.owner ?? item.owner ?? {}) as Record<
          string, unknown
        >;
        const pic = owner.profile_pic_url as string | undefined;
        if (pic && /^https?:\/\//i.test(pic)) return pic;
      }
      return null;
    }
    return null;
  } catch (e) {
    console.warn(
      `[backfill] Apify single-post fetch failed: ${
        e instanceof Error ? e.message : String(e)
      }`,
    );
    return null;
  }
}

async function bestPostCandidateForRestaurant(
  supabase: DbClient,
  restaurantId: number,
): Promise<{ coverUrl: string | null; score: number }> {
  const { data: links, error: linkError } = await supabase
    .from("restaurant_social_posts")
    .select("post_id")
    .eq("restaurant_id", restaurantId);
  if (linkError) {
    throw new Error(`Post link query failed: ${linkError.message}`);
  }
  const postIds = (links ?? []).map((link) => link.post_id);
  if (postIds.length === 0) return { coverUrl: null, score: 0 };

  const { data: postRows, error: postError } = await supabase
    .from("scraped_posts")
    .select(
      "cover_url, caption, hashtags, likes, comments, posted_at, scraped_at",
    )
    .in("id", postIds);
  if (postError) {
    throw new Error(`Post query failed: ${postError.message}`);
  }
  const best = selectBestImageCandidate(
    (postRows ?? []).map((post) => ({
      cover_url: post.cover_url,
      caption: post.caption,
      hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
      likes: post.likes ?? 0,
      comments: post.comments ?? 0,
      posted_at: post.posted_at ?? post.scraped_at,
    })),
    Date.now(),
  );
  return { coverUrl: best?.cover_url ?? null, score: best?.quality_score ?? 0 };
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Use POST" }, 405);

  let body: BackfillRequest;
  try { body = await req.json(); } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }
  if (
    !Array.isArray(body.restaurant_ids) || body.restaurant_ids.length === 0 ||
    body.restaurant_ids.length > 50
  ) {
    return jsonResponse({
      error: "restaurant_ids must be a non-empty array of up to 50 ids",
    }, 400);
  }
  const ids = body.restaurant_ids.filter((id) =>
    Number.isInteger(id) && id > 0
  );
  if (ids.length === 0) return jsonResponse({ error: "No valid restaurant_ids" }, 400);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  if (!(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }

  const results: BackfillResult[] = [];
  for (const restaurantId of ids) {
    try {
      const { data: restaurant, error: restErr } = await supabase
        .from("restaurants")
        .select("id, name, website, categories")
        .eq("id", restaurantId)
        .is("deleted_at", null)
        .maybeSingle();
      if (restErr) throw new Error(`Restaurant load failed: ${restErr.message}`);
      if (!restaurant) {
        results.push({
          restaurant_id: restaurantId, name: null, source: null,
          image_url: null, error: "not_found",
        });
        continue;
      }
      const { coverUrl, score } = await bestPostCandidateForRestaurant(
        supabase,
        restaurantId,
      );
      // Tier 2 (IG profile pic) costs an Apify run — only spend it when
      // tier 1 has no candidate at all.
      const ownerProfilePicUrl = coverUrl
        ? null
        : await fetchOwnerProfilePicForRestaurant(supabase, restaurantId);
      const chainResult = await persistRestaurantImageChain(
        supabase,
        restaurantId,
        {
          postImageUrl: coverUrl,
          postImageScore: score,
          ownerProfilePicUrl,
          websiteUrl: restaurant.website ?? null,
          category: (restaurant.categories ?? [])[0] ?? null,
        },
      );
      results.push({
        restaurant_id: restaurantId,
        name: restaurant.name ?? null,
        source: chainResult.source,
        image_url: chainResult.imageUrl,
        error: chainResult.source === null ? "all_tiers_failed" : null,
      });
    } catch (e) {
      results.push({
        restaurant_id: restaurantId, name: null, source: null,
        image_url: null,
        error: e instanceof Error ? e.message : String(e),
      });
    }
  }
  return jsonResponse({ results });
});
