/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// enrich-restaurants
// ----------------------------------------------------------------------------
// Uses LLM web search to fill in missing restaurant data (address, phone,
// business hours) for restaurants that have incomplete information.
//
// POST body: {
//   restaurant_ids?: number[],  -- specific IDs to enrich (omit for batch mode)
//   batch_size?: number,        -- max restaurants to process (default 10)
//   force?: boolean             -- re-enrich even if fields exist
// }
//
// Response: { enriched: number, skipped: number, failed: number, results: [...] }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
type DbClient = SupabaseClient<any, any, any, any, any>;

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest } from "../_shared/auth.ts";
import { fetchWithTimeout } from "../_shared/http.ts";
import { geocodeWithNominatim } from "../_shared/enrich.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Restaurant {
  id: number;
  name: string;
  city: string | null;
  address: string | null;
  phone: string | null;
  business_hours: unknown;
  latitude: number | null;
  longitude: number | null;
  instagram_location_id: string | null;
  categories: string[] | null;
}

interface EnrichmentResult {
  address: string | null;
  phone: string | null;
  business_hours: string | null;
  website: string | null;
  source: string;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    // Empty body is fine
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  if (!(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }

  const specificIds = Array.isArray(body.restaurant_ids)
    ? body.restaurant_ids.filter((id: unknown) => typeof id === "number")
    : null;
  const batchSize = typeof body.batch_size === "number"
    ? Math.max(1, Math.min(50, Math.trunc(body.batch_size)))
    : 10;
  const force = body.force === true;

  try {
    const result = await enrichBatch(supabase, specificIds, batchSize, force);
    return jsonResponse(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[enrich-restaurants] Error:`, message);
    return jsonResponse({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Core: find restaurants needing enrichment and process them
// ---------------------------------------------------------------------------

async function enrichBatch(
  supabase: DbClient,
  specificIds: number[] | null,
  batchSize: number,
  force: boolean,
) {
  // Find restaurants missing key fields
  let query = supabase
    .from("restaurants")
    .select(
      "id, name, city, address, phone, business_hours, latitude, longitude, instagram_location_id, categories",
    )
    .not("name", "is", null)
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (specificIds && specificIds.length > 0) {
    query = query.in("id", specificIds);
  } else if (!force) {
    // Only restaurants missing address, phone, coords, or have empty business_hours
    query = query.or(
      "address.is.null,address.eq.,phone.is.null,phone.eq.,business_hours.is.null,business_hours.eq.\"{}\",latitude.is.null",
    );
  }

  query = query.limit(batchSize);

  const { data: restaurants, error: fetchErr } = await query;
  if (fetchErr) {
    throw new Error(`Failed to fetch restaurants: ${fetchErr.message}`);
  }
  if (!restaurants || restaurants.length === 0) {
    return { enriched: 0, skipped: 0, failed: 0, results: [] };
  }

  let enriched = 0;
  let skipped = 0;
  let failed = 0;
  const results: Array<{ id: number; name: string; status: string; changes: string[] }> = [];

  for (const restaurant of restaurants) {
    const r = restaurant as Restaurant;
    try {
      const result = await enrichSingleRestaurant(supabase, r, force);
      if (result) {
        enriched++;
        results.push({
          id: r.id,
          name: r.name,
          status: "enriched",
          changes: result,
        });
      } else {
        skipped++;
        results.push({
          id: r.id,
          name: r.name,
          status: "skipped",
          changes: [],
        });
      }
    } catch (err) {
      failed++;
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[enrich] Failed for ${r.name}: ${message}`);
      results.push({
        id: r.id,
        name: r.name,
        status: "failed",
        changes: [message],
      });
    }

    // Small delay between LLM calls to avoid rate limiting
    await new Promise((r) => setTimeout(r, 500));
  }

  console.log(
    `[enrich-restaurants] Done: ${enriched} enriched, ${skipped} skipped, ${failed} failed`,
  );

  return { enriched, skipped, failed, results };
}

// ---------------------------------------------------------------------------
// Enrich a single restaurant using LLM
// ---------------------------------------------------------------------------

async function enrichSingleRestaurant(
  supabase: DbClient,
  restaurant: Restaurant,
  force: boolean,
): Promise<string[] | null> {
  // Check what fields are missing
  const needsAddress = !restaurant.address || restaurant.address.trim() === "";
  const needsPhone = !restaurant.phone || restaurant.phone.trim() === "";
  const needsHours =
    !restaurant.business_hours ||
    JSON.stringify(restaurant.business_hours) === "{}" ||
    JSON.stringify(restaurant.business_hours) === '""';
  const needsCoords = restaurant.latitude == null || restaurant.longitude == null;

  if (!force && !needsAddress && !needsPhone && !needsHours && !needsCoords) {
    return null; // Already has all fields
  }

  // Build search context for the LLM
  const searchParts = [restaurant.name];
  if (restaurant.city) searchParts.push(restaurant.city);
  if (restaurant.categories && restaurant.categories.length > 0) {
    searchParts.push(restaurant.categories[0]);
  }
  const searchQuery = searchParts.join(" ");

  // Ask the LLM to find restaurant details. May fail (missing key, outage,
  // parse error) — the coordinate safety net below must still run.
  const enrichment = await callLLMForEnrichment(
    searchQuery,
    restaurant.name,
    restaurant.city,
    restaurant.latitude,
    restaurant.longitude,
  );

  // Apply updates
  const updates: Record<string, unknown> = {};
  const changes: string[] = [];

  if (needsAddress && enrichment?.address) {
    updates.address = enrichment.address;
    changes.push(`address: ${enrichment.address}`);
  }
  if (needsPhone && enrichment?.phone) {
    updates.phone = enrichment.phone;
    changes.push(`phone: ${enrichment.phone}`);
  }
  if (needsHours && enrichment?.business_hours) {
    updates.business_hours = { status: enrichment.business_hours };
    changes.push(`hours: ${enrichment.business_hours}`);
  }

  // Geocode restaurants that still have no coordinates (free Nominatim pass).
  // Runs even when the LLM produced no updates, so coord-less restaurants are
  // always covered by the safety net.
  if (needsCoords) {
    const effectiveAddress = updates.address as string | undefined ??
      restaurant.address;
    const geoQuery = [effectiveAddress ?? restaurant.name, restaurant.city, "Malaysia"]
      .filter((part): part is string => !!part && part.trim().length > 0)
      .join(", ");
    const geo = await geocodeWithNominatim(geoQuery);
    if (geo) {
      updates.latitude = geo.lat;
      updates.longitude = geo.lng;
      changes.push(`coords: ${geo.lat.toFixed(5)}, ${geo.lng.toFixed(5)}`);
    }
  }

  if (Object.keys(updates).length === 0) return null;

  updates.updated_at = new Date().toISOString();

  const { error } = await supabase
    .from("restaurants")
    .update(updates)
    .eq("id", restaurant.id);

  if (error) {
    throw new Error(`Update failed: ${error.message}`);
  }

  return changes;
}

// ---------------------------------------------------------------------------
// LLM call to enrich restaurant data
// ---------------------------------------------------------------------------

async function callLLMForEnrichment(
  searchQuery: string,
  name: string,
  city: string | null,
  lat: number | null,
  lng: number | null,
): Promise<EnrichmentResult | null> {
  const apiKey = Deno.env.get("MIMO_API_KEY") ?? Deno.env.get("LLM_API_KEY") ??
    Deno.env.get("OPENAI_API_KEY");
  const baseUrl =
    (Deno.env.get("MIMO_BASE_URL") ?? Deno.env.get("LLM_BASE_URL") ??
      "https://api.openai.com/v1")
      .replace(/\/+$/, "");
  const model = Deno.env.get("MIMO_MODEL") ?? Deno.env.get("LLM_MODEL") ??
    Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

  if (!apiKey) {
    console.warn("[enrich] No LLM API key configured");
    return null;
  }

  const locationHint = lat !== null && lng !== null
    ? `\nCoordinates: ${lat}, ${lng} (Malaysia)`
    : "";

  const systemPrompt = `You are a restaurant data research assistant. Given a restaurant name and location, find its address, phone number, and business hours.

Search the web for information about this restaurant. Return STRICT JSON only:
{
  "address": string | null,      // full street address including area/postcode if found
  "phone": string | null,        // phone number with country code (e.g. +60 3-1234 5678)
  "business_hours": string | null, // e.g. "Mon-Sun 10:00 AM - 10:00 PM" or "Open until 9 PM"
  "website": string | null       // official website URL if found
}

Rules:
- Only return data you find from actual web sources. Do NOT invent or guess.
- If you cannot find reliable information for a field, return null for that field.
- For Malaysian restaurants, phone numbers typically start with +60 or 0.
- Business hours should be in a human-readable format.
- Return JSON with no markdown fences.`;

  const userPrompt = `Find details for: ${searchQuery}${locationHint}`;

  try {
    const resp = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    }, 30_000);

    if (!resp.ok) {
      console.error(`[enrich] LLM API error: ${resp.status}`);
      return null;
    }

    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) return null;

    const parsed = JSON.parse(content);
    return {
      address: parsed.address ?? null,
      phone: parsed.phone ?? null,
      business_hours: parsed.business_hours ?? null,
      website: parsed.website ?? null,
      source: "llm_web_search",
    };
  } catch (err) {
    console.error(
      `[enrich] LLM call failed for "${searchQuery}":`,
      err instanceof Error ? err.message : String(err),
    );
    return null;
  }
}
