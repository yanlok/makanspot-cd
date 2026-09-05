/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// geocode-restaurants
// ----------------------------------------------------------------------------
// Re-geocodes restaurants using the Mapbox Temporary Geocoding API (free tier:
// 100K requests/month). Updates latitude and longitude for restaurants that
// lack coordinates or that the caller explicitly asks to re-geocode.
//
// POST body: {
//   restaurant_ids?: number[],  -- specific IDs to geocode (omit for batch mode)
//   batch_size?: number,        -- max restaurants to process (default 10, max 50)
//   force?: boolean             -- re-geocode even if lat/lng already exist
// }
//
// Response: { geocoded: number, skipped: number, failed: number, results: [...] }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
type DbClient = SupabaseClient<any, any, any, any, any>;

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest } from "../_shared/auth.ts";
import { fetchWithTimeout } from "../_shared/http.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Restaurant {
  id: number;
  name: string;
  city: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
}

interface GeocodeResult {
  id: number;
  name: string;
  status: string;
  latitude: number | null;
  longitude: number | null;
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

  const mapboxToken = Deno.env.get("MAPBOX_ACCESS_TOKEN");
  if (!mapboxToken) {
    return jsonResponse(
      { error: "MAPBOX_ACCESS_TOKEN environment variable is not set" },
      500,
    );
  }

  try {
    const result = await geocodeBatch(supabase, mapboxToken, specificIds, batchSize, force);
    return jsonResponse(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[geocode-restaurants] Error:`, message);
    return jsonResponse({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Core: find restaurants needing geocoding and process them
// ---------------------------------------------------------------------------

async function geocodeBatch(
  supabase: DbClient,
  mapboxToken: string,
  specificIds: number[] | null,
  batchSize: number,
  force: boolean,
) {
  let query = supabase
    .from("restaurants")
    .select("id, name, city, address, latitude, longitude")
    .not("name", "is", null)
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (specificIds && specificIds.length > 0) {
    query = query.in("id", specificIds);
  } else if (!force) {
    // Only restaurants missing valid coordinates
    query = query.or(
      "latitude.is.null,longitude.is.null,latitude.eq.0,longitude.eq.0",
    );
  }

  query = query.limit(batchSize);

  const { data: restaurants, error: fetchErr } = await query;
  if (fetchErr) {
    throw new Error(`Failed to fetch restaurants: ${fetchErr.message}`);
  }
  if (!restaurants || restaurants.length === 0) {
    return { geocoded: 0, skipped: 0, failed: 0, results: [] };
  }

  let geocoded = 0;
  let skipped = 0;
  let failed = 0;
  const results: GeocodeResult[] = [];

  for (const restaurant of restaurants) {
    const r = restaurant as Restaurant;
    try {
      // Skip if already has valid coordinates and force is not set
      if (
        !force &&
        typeof r.latitude === "number" &&
        Number.isFinite(r.latitude) &&
        typeof r.longitude === "number" &&
        Number.isFinite(r.longitude)
      ) {
        skipped++;
        results.push({
          id: r.id,
          name: r.name,
          status: "skipped",
          latitude: r.latitude,
          longitude: r.longitude,
        });
      } else {
        const coords = await geocodeSingle(r, mapboxToken);
        if (coords) {
          // Update database
          const { error: updateErr } = await supabase
            .from("restaurants")
            .update({
              latitude: coords.latitude,
              longitude: coords.longitude,
              updated_at: new Date().toISOString(),
            })
            .eq("id", r.id);

          if (updateErr) {
            throw new Error(`Update failed: ${updateErr.message}`);
          }

          geocoded++;
          results.push({
            id: r.id,
            name: r.name,
            status: "geocoded",
            latitude: coords.latitude,
            longitude: coords.longitude,
          });
        } else {
          // No features returned — keep existing coords
          skipped++;
          results.push({
            id: r.id,
            name: r.name,
            status: "skipped",
            latitude: r.latitude,
            longitude: r.longitude,
          });
        }
      }
    } catch (err) {
      failed++;
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[geocode] Failed for ${r.name}: ${message}`);
      results.push({
        id: r.id,
        name: r.name,
        status: "failed",
        latitude: r.latitude,
        longitude: r.longitude,
      });
    }

    // Rate limit: 1 second between geocoding API calls
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  console.log(
    `[geocode-restaurants] Done: ${geocoded} geocoded, ${skipped} skipped, ${failed} failed`,
  );

  return { geocoded, skipped, failed, results };
}

// ---------------------------------------------------------------------------
// Geocode a single restaurant via Mapbox
// ---------------------------------------------------------------------------

async function geocodeSingle(
  restaurant: Restaurant,
  mapboxToken: string,
): Promise<{ latitude: number; longitude: number } | null> {
  // Build geocoding query from available fields
  const parts: string[] = [];
  if (restaurant.name) parts.push(restaurant.name);
  if (restaurant.address) parts.push(restaurant.address);
  if (restaurant.city) parts.push(restaurant.city);
  parts.push("Malaysia");

  const query = parts.join(" ");
  const encoded = encodeURIComponent(query);

  const url =
    `https://api.mapbox.com/geocoding/v5/mapbox.places/${encoded}.json` +
    `?access_token=${mapboxToken}&limit=1`;

  const resp = await fetchWithTimeout(url, {}, 15_000);

  if (!resp.ok) {
    console.error(`[geocode] Mapbox API error: ${resp.status} for "${query}"`);
    return null;
  }

  const data = await resp.json();
  const feature = data?.features?.[0];
  if (!feature?.center || !Array.isArray(feature.center)) {
    return null;
  }

  const [longitude, latitude] = feature.center;
  if (typeof longitude !== "number" || typeof latitude !== "number") {
    return null;
  }
  if (!Number.isFinite(longitude) || !Number.isFinite(latitude)) {
    return null;
  }

  return { latitude, longitude };
}
