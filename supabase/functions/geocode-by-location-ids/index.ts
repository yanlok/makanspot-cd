import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ACTOR_ID = "apify%2Finstagram-search-scraper";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!serviceKey || token !== serviceKey) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const body = await req.json().catch(() => ({}));
  const specificIds: number[] | undefined = body.restaurant_ids;
  const batchSize = Math.min(Math.max(body.batch_size ?? 10, 1), 50);
  const force: boolean = body.force ?? false;

  const apifyToken = Deno.env.get("APIFY_TOKEN");
  if (!apifyToken) {
    return new Response(
      JSON.stringify({ error: "APIFY_TOKEN not configured" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  let query = supabase
    .from("restaurants")
    .select("id, name, city, instagram_location_id, latitude, longitude")
    .is("deleted_at", null)
    .not("instagram_location_id", "is", null);

  if (specificIds?.length) {
    query = query.in("id", specificIds);
  } else if (!force) {
    query = query.or(
      "latitude.is.null,and(latitude.eq.3.151696,longitude.eq.101.694237)",
    );
  }

  query = query.order("created_at", { ascending: false }).limit(batchSize);

  const { data: restaurants, error: fetchErr } = await query;
  if (fetchErr || !restaurants?.length) {
    return new Response(
      JSON.stringify({
        error: fetchErr?.message ?? "No restaurants found",
        geocoded: 0, skipped: 0, failed: 0,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const results: Array<{
    id: number; name: string;
    old_lat: number | null; old_lng: number | null;
    new_lat: number; new_lng: number;
  }> = [];
  let skipped = 0;
  let failed = 0;

  for (let i = 0; i < restaurants.length; i++) {
    const r = restaurants[i];
    const searchTerm = [r.name, r.city, "Malaysia"]
      .filter((p) => p && p.trim().length > 0)
      .join(" ");

    console.log(
      `[${i + 1}/${restaurants.length}] Searching: "${searchTerm}" (location_id: ${r.instagram_location_id})`,
    );

    try {
      // Search Instagram by restaurant name + city
      const searchResp = await fetch(
        `https://api.apify.com/v2/acts/${ACTOR_ID}/runs?token=${apifyToken}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            search: searchTerm,
            searchType: "place",
            searchLimit: 5,
            addParentData: false,
            timeoutSecs: 120,
            memoryMbytes: 4096,
          }),
        },
      );

      if (!searchResp.ok) {
        const errText = await searchResp.text().catch(() => "");
        console.log(`  → Apify start failed: ${searchResp.status} ${errText}`);
        failed++;
        continue;
      }

      const startData = await searchResp.json();
      const runId = startData.data?.id;
      if (!runId) {
        console.log(`  → No run ID returned`);
        failed++;
        continue;
      }

      // Poll for completion (max 120 seconds)
      let place: { location_id?: string; lat?: number; lng?: number } | null = null;
      for (let attempt = 0; attempt < 24; attempt++) {
        await new Promise((resolve) => setTimeout(resolve, 5000));

        const statusResp = await fetch(
          `https://api.apify.com/v2/actor-runs/${runId}?token=${apifyToken}`,
        );
        if (!statusResp.ok) continue;

        const statusData = await statusResp.json();
        const status = statusData.data?.status;

        if (status === "SUCCEEDED") {
          const datasetId = statusData.data?.defaultDatasetId;
          if (datasetId) {
            const itemsResp = await fetch(
              `https://api.apify.com/v2/datasets/${datasetId}/items?token=${apifyToken}&format=json`,
            );
            if (itemsResp.ok) {
              const items = await itemsResp.json();
              if (Array.isArray(items) && items.length > 0) {
                // Match by instagram_location_id first
                const match = items.find(
                  (item: { location_id?: string }) =>
                    item.location_id &&
                    String(item.location_id) === String(r.instagram_location_id),
                );
                place = match ?? items[0];
                console.log(
                  `  → Found ${items.length} results, matched: ${match ? "by ID" : "fallback to first"}`,
                );
              }
            }
          }
          break;
        } else if (status === "FAILED" || status === "ABORTED") {
          console.log(`  → Apify run ${status}`);
          break;
        }
      }

      if (
        place &&
        typeof place.lat === "number" && Number.isFinite(place.lat) &&
        typeof place.lng === "number" && Number.isFinite(place.lng)
      ) {
        const inMalaysia =
          place.lat >= -1.5 && place.lat <= 7.5 &&
          place.lng >= 99.0 && place.lng <= 119.5;

        if (inMalaysia) {
          const latDiff = Math.abs((r.latitude ?? 0) - place.lat);
          const lngDiff = Math.abs((r.longitude ?? 0) - place.lng);

          if (latDiff > 0.001 || lngDiff > 0.001 || r.latitude == null) {
            await supabase
              .from("restaurants")
              .update({
                latitude: place.lat,
                longitude: place.lng,
                updated_at: new Date().toISOString(),
              })
              .eq("id", r.id);

            results.push({
              id: r.id, name: r.name,
              old_lat: r.latitude, old_lng: r.longitude,
              new_lat: place.lat, new_lng: place.lng,
            });
            console.log(
              `  → ${r.latitude ?? "null"},${r.longitude ?? "null"} → ${place.lat},${place.lng}`,
            );
          } else {
            skipped++;
            console.log(`  → unchanged (within 100m)`);
          }
        } else {
          failed++;
          console.log(`  → rejected (outside Malaysia: ${place.lat},${place.lng})`);
        }
      } else {
        failed++;
        console.log(`  → no valid coordinates in response`);
      }
    } catch (error) {
      failed++;
      console.log(`  → error: ${error instanceof Error ? error.message : String(error)}`);
    }

    // Rate limit: 3 seconds between Apify calls
    if (i < restaurants.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }

  return new Response(
    JSON.stringify({ geocoded: results.length, skipped, failed, results }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
