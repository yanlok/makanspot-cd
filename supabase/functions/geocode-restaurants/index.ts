/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// geocode-restaurants
// ----------------------------------------------------------------------------
// Re-geocodes restaurants using the Mapbox Temporary Geocoding API (free tier:
// 100K requests/month). Resolves specific addresses via LLM when missing or
// clustered, and enforces anti-centroid filtering.
//
// POST body: {
//   restaurant_ids?: number[],      -- specific IDs to geocode (omit for batch mode)
//   batch_size?: number,            -- max restaurants to process (default 20, max 100)
//   force?: boolean,                -- re-geocode even if lat/lng already exist
//   remove_unresolvable?: boolean   -- soft-delete restaurants whose location cannot be resolved
// }
//
// Response: { geocoded: number, deleted: number, skipped: number, failed: number, results: [...] }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
type DbClient = SupabaseClient<any, any, any, any, any>;

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest } from "../_shared/auth.ts";
import {
  geocodeWithMapbox,
  isBroadCentroid,
  isInMalaysia,
  resolveAddressWithLLM,
} from "../_shared/enrich.ts";

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
  resolved_address?: string | null;
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
    ? Math.max(1, Math.min(100, Math.trunc(body.batch_size)))
    : 20;
  const force = body.force === true;
  const removeUnresolvable = body.remove_unresolvable === true;

  const mapboxToken =
    Deno.env.get("MAPBOX_ACCESS_TOKEN") ?? Deno.env.get("MAPBOX_TOKEN");
  if (!mapboxToken) {
    return jsonResponse(
      { error: "MAPBOX_ACCESS_TOKEN environment variable is not set" },
      500,
    );
  }

  try {
    const result = await geocodeBatch(
      supabase,
      mapboxToken,
      specificIds,
      batchSize,
      force,
      removeUnresolvable,
    );
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
  removeUnresolvable: boolean,
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
    // Target restaurants missing coordinates or falling into known centroid clusters
    query = query.or(
      "latitude.is.null,longitude.is.null,latitude.eq.0,longitude.eq.0," +
        "and(latitude.gte.4.45,latitude.lte.4.55)," +
        "and(latitude.gte.3.045,latitude.lte.3.055)," +
        "and(latitude.gte.3.095,latitude.lte.3.105)",
    );
  }

  query = query.limit(batchSize);

  const { data: restaurants, error: fetchErr } = await query;
  if (fetchErr) {
    throw new Error(`Failed to fetch restaurants: ${fetchErr.message}`);
  }
  if (!restaurants || restaurants.length === 0) {
    return { geocoded: 0, deleted: 0, skipped: 0, failed: 0, results: [] };
  }

  // Filter for candidates that need geocoding
  const candidates = (restaurants as Restaurant[]).filter((r) => {
    if (force) return true;
    const lat = r.latitude;
    const lng = r.longitude;
    if (lat === null || lng === null) return true;
    if (!isInMalaysia(lat, lng)) return true;
    if (isBroadCentroid(lat, lng)) return true;
    return false;
  }).slice(0, batchSize);

  let geocoded = 0;
  let deleted = 0;
  let skipped = 0;
  let failed = 0;
  const results: GeocodeResult[] = [];

  for (const r of candidates) {
    try {
      let addrToUse = r.address;
      let newAddressDiscovered: string | null = null;

      // If address is absent or vague (< 10 chars), consult LLM to identify specific street/mall
      if (!addrToUse || addrToUse.trim().length < 10) {
        const llmAddress = await resolveAddressWithLLM(r.name, r.city);
        if (llmAddress) {
          addrToUse = llmAddress;
          newAddressDiscovered = llmAddress;
        }
      }

      // Geocode using Mapbox temporary API, rejecting broad city/country centroids
      let geo: { lat: number; lng: number } | null = null;
      if (addrToUse && addrToUse.trim().length > 6) {
        const addrQuery = [addrToUse.trim(), r.city, "Malaysia"]
          .filter(Boolean)
          .join(", ");
        geo = await geocodeWithMapbox(addrQuery, mapboxToken, {
          rejectBroadArea: true,
        });
      }

      if (!geo && r.name) {
        const nameQuery = [r.name.trim(), r.city, "Malaysia"]
          .filter(Boolean)
          .join(", ");
        geo = await geocodeWithMapbox(nameQuery, mapboxToken, {
          rejectBroadArea: true,
        });
      }

      if (geo && isInMalaysia(geo.lat, geo.lng) && !isBroadCentroid(geo.lat, geo.lng)) {
        const updateData: Record<string, unknown> = {
          latitude: geo.lat,
          longitude: geo.lng,
          updated_at: new Date().toISOString(),
        };
        if (newAddressDiscovered) {
          updateData.address = newAddressDiscovered;
        }

        const { error: updateErr } = await supabase
          .from("restaurants")
          .update(updateData)
          .eq("id", r.id);

        if (updateErr) {
          throw new Error(`Update failed: ${updateErr.message}`);
        }

        geocoded++;
        results.push({
          id: r.id,
          name: r.name,
          status: "geocoded",
          latitude: geo.lat,
          longitude: geo.lng,
          resolved_address: newAddressDiscovered ?? r.address,
        });
      } else {
        // Location cannot be accurately determined
        if (removeUnresolvable) {
          await supabase
            .from("restaurants")
            .update({
              deleted_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq("id", r.id);

          deleted++;
          results.push({
            id: r.id,
            name: r.name,
            status: "deleted_unresolvable",
            latitude: r.latitude,
            longitude: r.longitude,
          });
        } else {
          skipped++;
          results.push({
            id: r.id,
            name: r.name,
            status: "unresolved_skipped",
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

    // Rate limit: 500ms between calls
    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  console.log(
    `[geocode-restaurants] Done: ${geocoded} geocoded, ${deleted} deleted, ${skipped} skipped, ${failed} failed`,
  );

  return { geocoded, deleted, skipped, failed, results };
}
