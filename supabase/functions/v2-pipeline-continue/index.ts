/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// v2-pipeline-continue
// ----------------------------------------------------------------------------
// State machine worker for the v2 scraping pipeline. Processes one step per
// invocation and chains to itself via EdgeRuntime.waitUntil, keeping each
// call within the Supabase Edge Function timeout.
//
// Steps:
//   1. scrape   — poll Apify run until done, record dataset_id + cost
//   2. ingest   — fetch 10 posts from dataset, upsert into v2_scraped_posts
//   3. detect   — filter posts (v2IsLikelyNotRestaurant), derive categories
//   4. resolve  — match posts to existing restaurants via v2_restaurant_sources
//   5. enrich   — LLM extraction + geocoding, insert new restaurants
//   6. metrics  — recompute social metrics for restaurants touched by this run
//   7. complete — update v2_scrape_runs totals, update discovery source metrics
//
// POST body: { job_id: string }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
type DbClient = SupabaseClient<any, any, any, any, any>;

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isServiceRoleRequest } from "../_shared/v2-auth.ts";
import {
  type IgRecord,
  toV2PlaceCandidate,
  toV2StagingRow,
  v2ApplyAuthoritativeLocation,
  v2BoundLocationPostItems,
  v2BoundLocationPostTargets,
  v2IsLikelyFoodPlace,
  type V2PlaceCandidate,
  v2PlacePostsToRows,
  v2ShouldQueueLocationPosts,
  type V2StagingRow,
} from "../_shared/v2-apify.ts";
import {
  v2DeriveCategories,
  v2ExtractVenue,
  v2Geocode,
  v2IsLikelyNotRestaurant,
  v2NameRelation,
  v2NormalizeName,
  v2PersistPrimaryImage,
  v2PopularityScore,
  v2ReverseGeocode,
  v2SelectBestImageCandidate,
  v2SumComponentCosts,
  v2TrendScore,
} from "../_shared/v2-enrich.ts";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const BATCH_SIZE = 10;
const APIFY_POLL_DELAY_MS = 10_000;
const MAX_RETRIES = 30; // ~5 min at 10s intervals

// ---------------------------------------------------------------------------
// Geographic + scheduling helpers
// ---------------------------------------------------------------------------

/** Malaysia bounding box (Peninsular + East Malaysia). */
function isInMalaysia(lat: number, lng: number): boolean {
  return lat >= 0.8 && lat <= 7.4 && lng >= 99.6 && lng <= 119.3;
}

/**
 * Snap a UTC epoch-ms to the next business-hour slot in MYT (UTC+8).
 * Business window: 08:00–20:00 MYT.  If the input already falls inside
 * the window the same day, it is returned unchanged.  Otherwise we roll
 * forward to 08:00 of the next eligible day.
 */
function nextBusinessHour(dateMs: number): string {
  const MYT_OFFSET_MS = 8 * 3600_000;
  const WORK_START_H = 8;
  const WORK_END_H = 20;

  // Shift to MYT and extract calendar fields
  const mytMs = dateMs + MYT_OFFSET_MS;
  const d = new Date(mytMs);
  const hour = d.getUTCHours();

  // UTC timestamp of midnight MYT (start of the MYT day)
  const startOfMytDay = mytMs -
    hour * 3600_000 -
    d.getUTCMinutes() * 60_000 -
    d.getUTCSeconds() * 1000 -
    d.getUTCMilliseconds();

  let targetMytMs: number;
  if (hour < WORK_START_H) {
    // Before window → 08:00 MYT today
    targetMytMs = startOfMytDay + WORK_START_H * 3600_000;
  } else if (hour >= WORK_END_H) {
    // After window → 08:00 MYT tomorrow
    targetMytMs = startOfMytDay + 24 * 3600_000 + WORK_START_H * 3600_000;
  } else {
    // Inside window → keep as-is
    return new Date(dateMs).toISOString();
  }

  // Convert MYT target back to UTC
  return new Date(targetMytMs - MYT_OFFSET_MS).toISOString();
}

// ---------------------------------------------------------------------------
// Pipeline state stored in pipeline_jobs.result JSONB
// ---------------------------------------------------------------------------

interface V2PipelineState {
  v2_scrape_run_id?: string;
  apify_run_id?: string;
  active_component_id?: string;
  source_ids?: number[];
  dataset_kind?: "place" | "post";
  result_limit?: number;
  new_post_ids?: number[];
  affected_restaurant_ids?: number[];
  location_post_targets?: Array<
    { restaurant_id: number; location_id: string; url: string }
  >;
  location_posts_run_id?: string;
  location_posts_dataset_id?: string;
  location_posts_actor_completed?: boolean;
  component_item_count?: number;
  current_step?:
    | "scrape"
    | "ingest"
    | "location_posts_scrape"
    | "location_posts_ingest"
    | "detect"
    | "resolve"
    | "enrich"
    | "metrics"
    | "complete";
  batch_index?: number;
  retry_count?: number;
  started_at?: string;
  dataset_id?: string;
  cost_usd?: number;
  stats: {
    posts_received: number;
    new_posts: number;
    candidates_detected: number;
    candidates_enriched: number;
    restaurants_created: number;
    places_received?: number;
    places_filtered?: number;
    location_posts_received?: number;
    posts_skipped: number;
    posts_failed: number;
  };
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
  if (!(await isServiceRoleRequest(req))) {
    return jsonResponse({ error: "service_role_required" }, 403);
  }

  const { job_id: jobId } = await req.json();
  if (!jobId) {
    return jsonResponse({ error: "Missing job_id" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // --- Read current job state ---
  const { data: job, error: readErr } = await supabase
    .from("pipeline_jobs")
    .select("id, status, result")
    .eq("id", jobId)
    .single();

  if (readErr || !job) {
    console.error(`[v2-continue] Job ${jobId} not found:`, readErr?.message);
    await failOnlyActiveScrapeRun(
      supabase,
      `Continuation job ${jobId} could not be read: ${
        readErr?.message ?? "not found"
      }`,
    );
    return jsonResponse({ error: "Job not found" }, 404);
  }

  if (job.status !== "running") {
    console.log(`[v2-continue] Job ${jobId} is ${job.status} — skipping`);
    return jsonResponse({ ok: true, skipped: true });
  }

  const state: V2PipelineState = (job.result as V2PipelineState) ?? {
    stats: {
      posts_received: 0,
      new_posts: 0,
      candidates_detected: 0,
      candidates_enriched: 0,
      restaurants_created: 0,
      posts_skipped: 0,
      posts_failed: 0,
    },
  };
  const step = state.current_step ?? "scrape";

  try {
    if (step === "scrape") {
      await handleScrape(supabase, jobId, state);
    } else if (step === "ingest") {
      await handleIngest(supabase, jobId, state);
    } else if (step === "location_posts_scrape") {
      await handleLocationPostsScrape(supabase, jobId, state);
    } else if (step === "location_posts_ingest") {
      await handleLocationPostsIngest(supabase, jobId, state);
    } else if (step === "detect") {
      await handleDetect(supabase, jobId, state);
    } else if (step === "resolve") {
      await handleResolve(supabase, jobId, state);
    } else if (step === "enrich") {
      await handleEnrich(supabase, jobId, state);
    } else if (step === "metrics") {
      await handleMetrics(supabase, jobId, state);
    } else if (step === "complete") {
      await handleComplete(supabase, jobId, state);
    } else {
      await markFailed(
        supabase,
        jobId,
        state,
        `Unknown pipeline step: ${step}`,
      );
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[v2-continue] Job ${jobId} failed:`, msg);
    await abortActiveFollowupIfNeeded(state);
    await markFailed(supabase, jobId, state, msg);
  }

  return jsonResponse({ ok: true });
});

// ---------------------------------------------------------------------------
// Step 1: Scrape — poll Apify until finished
// ---------------------------------------------------------------------------

async function handleScrape(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const runId = state.apify_run_id;
  if (!runId) {
    await markFailed(
      supabase,
      jobId,
      state,
      "No apify_run_id in pipeline state",
    );
    return;
  }

  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) {
    await markFailed(supabase, jobId, state, "APIFY_TOKEN not configured");
    return;
  }

  const resp = await fetch(
    `https://api.apify.com/v2/actor-runs/${runId}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );

  if (!resp.ok) {
    const retries = (state.retry_count ?? 0) + 1;
    if (retries >= MAX_RETRIES) {
      await markFailed(
        supabase,
        jobId,
        state,
        `Apify poll failed ${retries} times (last: ${resp.status})`,
      );
      return;
    }
    state.retry_count = retries;
    await updateState(supabase, jobId, state);
    console.warn(
      `[v2-continue] Apify poll failed (${resp.status}), retry ${retries}/${MAX_RETRIES}`,
    );
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
    return;
  }

  const data = await resp.json();
  const apifyStatus = data.data?.status;

  if (apifyStatus === "SUCCEEDED") {
    const datasetId = data.data?.defaultDatasetId;
    if (!datasetId) {
      await markFailed(
        supabase,
        jobId,
        state,
        "Apify succeeded but no dataset ID",
      );
      return;
    }

    state.cost_usd = typeof data.data?.usageTotalUsd === "number"
      ? data.data.usageTotalUsd
      : 0;
    state.dataset_id = datasetId;
    state.current_step = "ingest";
    state.batch_index = 0;
    state.retry_count = 0;

    await updateState(supabase, jobId, state);
    if (state.active_component_id) {
      const { error: componentError } = await supabase
        .from("v2_scrape_run_components").update({
          status: "completed",
          dataset_id: datasetId,
          cost_usd: state.cost_usd,
          completed_at: new Date().toISOString(),
        }).eq("id", state.active_component_id);
      if (componentError) {
        throw new Error(
          `Discovery component update failed: ${componentError.message}`,
        );
      }
    }
    if (state.v2_scrape_run_id) {
      const { error: traceError } = await supabase.from("v2_scrape_runs")
        .update({ dataset_id: datasetId, cost_usd: state.cost_usd })
        .eq("id", state.v2_scrape_run_id);
      if (traceError) {
        throw new Error(`Scrape trace update failed: ${traceError.message}`);
      }
    }
    console.log(
      `[v2-continue] Job ${jobId}: scrape done, dataset=${datasetId}, cost=$${state.cost_usd}`,
    );
    await scheduleContinue(jobId, 0);
  } else if (
    apifyStatus === "FAILED" ||
    apifyStatus === "ABORTED" ||
    apifyStatus === "TIMED-OUT"
  ) {
    await markFailed(supabase, jobId, state, `Apify run ${apifyStatus}`);
  } else {
    // Still running — check again after delay
    state.retry_count = 0;
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
  }
}

// ---------------------------------------------------------------------------
// Step 2: Ingest — fetch 10 posts from dataset, upsert into v2_scraped_posts
// ---------------------------------------------------------------------------

async function handleIngest(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const datasetId = state.dataset_id;
  if (!datasetId) {
    await markFailed(supabase, jobId, state, "No dataset_id in pipeline state");
    return;
  }

  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) {
    await markFailed(supabase, jobId, state, "APIFY_TOKEN not configured");
    return;
  }

  const offset = (state.batch_index ?? 0) * BATCH_SIZE;

  const resp = await fetch(
    `https://api.apify.com/v2/datasets/${datasetId}/items?format=json&offset=${offset}&limit=${BATCH_SIZE}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );

  if (!resp.ok) {
    const retries = (state.retry_count ?? 0) + 1;
    if (retries >= MAX_RETRIES) {
      await markFailed(
        supabase,
        jobId,
        state,
        `Dataset fetch failed ${retries} times (last: ${resp.status})`,
      );
      return;
    }
    state.retry_count = retries;
    await updateState(supabase, jobId, state);
    console.warn(
      `[v2-continue] Dataset fetch failed (${resp.status}), retry ${retries}/${MAX_RETRIES}`,
    );
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
    return;
  }

  const items: IgRecord[] = await resp.json();

  if (items.length === 0) {
    // No more dataset items. Only posts inserted by this run continue through
    // post processing; a replay therefore reports new_posts=0 and cannot reset
    // previously promoted/skipped/failed rows.
    if (state.active_component_id) {
      const { error } = await supabase.from("v2_scrape_run_components")
        .update({ item_count: state.component_item_count ?? 0 })
        .eq("id", state.active_component_id);
      if (error) {
        throw new Error(`Discovery item-count update failed: ${error.message}`);
      }
    }
    if (
      state.dataset_kind === "place" &&
      (state.location_post_targets?.length ?? 0) > 0
    ) {
      await startLocationPostsComponent(supabase, jobId, state);
      return;
    }
    state.current_step = "detect";
    state.batch_index = 0;
    state.retry_count = 0;
    await updateState(supabase, jobId, state);
    console.log(
      `[v2-continue] Job ${jobId}: ingest done, ${state.stats.new_posts} new posts ` +
        `(${state.stats.posts_received} received)`,
    );
    await scheduleContinue(jobId, 0);
    return;
  }

  // Convert and insert without an update-on-conflict. Updating a duplicate row
  // would incorrectly reset a terminal status to pending.
  let newCount = 0;
  let skippedCount = 0;

  for (const item of items) {
    if (state.dataset_kind === "place") {
      state.stats.places_received = (state.stats.places_received ?? 0) + 1;
      const place = toV2PlaceCandidate(item);
      if (!place) {
        state.stats.places_filtered = (state.stats.places_filtered ?? 0) + 1;
        skippedCount++;
        continue;
      }

      if (v2IsLikelyFoodPlace(place)) {
        // Reject places with coordinates outside Malaysia
        if (
          place.latitude !== null && place.longitude !== null &&
          !isInMalaysia(place.latitude, place.longitude)
        ) {
          state.stats.places_filtered =
            (state.stats.places_filtered ?? 0) + 1;
          skippedCount++;
          // Still stage embedded posts — they may reference other locations
        } else {
          const restaurantId = await upsertPlaceRestaurant(
            supabase,
            place,
            state,
          );
          if (restaurantId) {
            addAffectedRestaurant(state, restaurantId);
            await maybeQueueLocationPosts(supabase, state, restaurantId, place);
          }
        }
      } else {
        state.stats.places_filtered = (state.stats.places_filtered ?? 0) + 1;
        skippedCount++;
      }

      // Embedded posts remain useful staging input even when the parent place
      // is explicitly non-food and therefore not canonicalized.
      for (const row of v2PlacePostsToRows(place)) {
        const postId = await insertNewPost(supabase, row);
        if (postId !== null) {
          addNewPost(state, postId);
          newCount++;
        }
      }
    } else {
      const row = toV2StagingRow(item);
      if (!row) {
        skippedCount++;
        continue;
      }
      const postId = await insertNewPost(supabase, row);
      if (postId !== null) {
        addNewPost(state, postId);
        newCount++;
      }
    }
  }

  state.stats.posts_received += items.length;
  state.component_item_count = (state.component_item_count ?? 0) + items.length;
  state.stats.new_posts += newCount;
  state.batch_index = (state.batch_index ?? 0) + 1;
  state.retry_count = 0;
  await updateState(supabase, jobId, state);

  console.log(
    `[v2-continue] Job ${jobId}: ingest batch ${state.batch_index}, ` +
      `new=${newCount}, skipped=${skippedCount} (total: ${state.stats.new_posts})`,
  );

  await scheduleContinue(jobId, 0);
}

async function maybeQueueLocationPosts(
  supabase: DbClient,
  state: V2PipelineState,
  restaurantId: number,
  place: V2PlaceCandidate,
) {
  if (!place.external_id) return;
  const { data: primary, error } = await supabase.from("v2_restaurant_images")
    .select("id").eq("restaurant_id", restaurantId).eq("is_primary", true)
    .limit(1).maybeSingle();
  if (error) throw new Error(`Primary image check failed: ${error.message}`);
  const hasEmbeddedCover = v2PlacePostsToRows(place).some((row) =>
    !!row.cover_url
  );
  if (
    !v2ShouldQueueLocationPosts({
      hasPrimary: !!primary,
      hasEmbeddedCover,
      exactLocationUrl: place.url,
    })
  ) return;
  state.location_post_targets ??= [];
  if (state.location_post_targets.length >= 1) return;
  if (
    !state.location_post_targets.some((target) =>
      target.restaurant_id === restaurantId
    )
  ) {
    state.location_post_targets.push({
      restaurant_id: restaurantId,
      location_id: place.external_id,
      url: place.url!,
    });
  }
}

async function startLocationPostsComponent(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const runId = state.v2_scrape_run_id;
  const token = Deno.env.get("APIFY_TOKEN");
  if (!runId || !token) throw new Error("Cannot start location-post component");
  const { data: component, error } = await supabase
    .from("v2_scrape_run_components").insert({
      scrape_run_id: runId,
      component_type: "location_posts",
      status: "pending",
      actor_id: "apify/instagram-scraper",
    }).select("id").single();
  if (error || !component) {
    throw new Error(`Location-post component insert failed: ${error?.message}`);
  }

  let actorRunId: string | null = null;
  try {
    const response = await fetch(
      "https://api.apify.com/v2/acts/apify%2Finstagram-scraper/runs",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          directUrls: v2BoundLocationPostTargets(
            state.location_post_targets ?? [],
          ).map((target) => target.url),
          resultsType: "posts",
          resultsLimit: 3,
          addParentData: true,
        }),
      },
    );
    if (!response.ok) {
      throw new Error(
        `Location-post actor start failed (${response.status}): ${await response
          .text()}`,
      );
    }
    actorRunId = (await response.json()).data?.id ?? null;
    if (!actorRunId) throw new Error("Location-post actor returned no run ID");

    state.location_posts_run_id = actorRunId;
    state.active_component_id = component.id;
    state.component_item_count = 0;
    state.current_step = "location_posts_scrape";
    state.batch_index = 0;
    const [componentUpdate] = await Promise.all([
      supabase.from("v2_scrape_run_components").update({
        status: "running",
        apify_run_id: actorRunId,
        started_at: new Date().toISOString(),
      }).eq("id", component.id),
      updateState(supabase, jobId, state),
    ]);
    if (componentUpdate.error) {
      throw new Error(
        `Location-post component init failed: ${componentUpdate.error.message}`,
      );
    }
  } catch (error) {
    if (actorRunId) await abortActorRun(token, actorRunId);
    const message = error instanceof Error ? error.message : String(error);
    await supabase.from("v2_scrape_run_components").update({
      status: "failed",
      error: message,
      completed_at: new Date().toISOString(),
    }).eq("id", component.id);
    throw error;
  }
  await scheduleContinue(jobId, 0);
}

async function handleLocationPostsScrape(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const runId = state.location_posts_run_id;
  const token = Deno.env.get("APIFY_TOKEN");
  if (!runId || !token) throw new Error("Missing location-post actor state");
  const response = await fetch(`https://api.apify.com/v2/actor-runs/${runId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    throw new Error(`Location-post poll failed (${response.status})`);
  }
  const actor = (await response.json()).data;
  if (["FAILED", "ABORTED", "TIMED-OUT"].includes(actor?.status)) {
    state.location_posts_actor_completed = true;
    await updateState(supabase, jobId, state);
    await markComponentFailed(
      supabase,
      state.active_component_id,
      `Location-post actor ${actor.status}`,
    );
    throw new Error(`Location-post actor ${actor.status}`);
  }
  if (actor?.status !== "SUCCEEDED") {
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
    return;
  }
  state.location_posts_actor_completed = true;
  if (!actor.defaultDatasetId) {
    throw new Error("Location-post actor returned no dataset");
  }
  state.location_posts_dataset_id = actor.defaultDatasetId;
  state.current_step = "location_posts_ingest";
  state.batch_index = 0;
  const { error } = await supabase.from("v2_scrape_run_components").update({
    status: "completed",
    dataset_id: actor.defaultDatasetId,
    cost_usd: actor.usageTotalUsd ?? 0,
    completed_at: new Date().toISOString(),
  }).eq("id", state.active_component_id);
  if (error) {
    throw new Error(
      `Location-post component completion failed: ${error.message}`,
    );
  }
  await updateState(supabase, jobId, state);
  await scheduleContinue(jobId, 0);
}

async function handleLocationPostsIngest(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const token = Deno.env.get("APIFY_TOKEN");
  const datasetId = state.location_posts_dataset_id;
  if (!token || !datasetId) {
    throw new Error("Missing location-post dataset state");
  }
  const alreadyProcessed = state.component_item_count ?? 0;
  if (alreadyProcessed >= 3) {
    await finishLocationPostsIngest(supabase, jobId, state);
    return;
  }
  const offset = alreadyProcessed;
  const limit = Math.min(BATCH_SIZE, 3 - alreadyProcessed);
  const response = await fetch(
    `https://api.apify.com/v2/datasets/${datasetId}/items?format=json&offset=${offset}&limit=${limit}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!response.ok) {
    throw new Error(`Location-post dataset fetch failed (${response.status})`);
  }
  const items = v2BoundLocationPostItems<IgRecord>(
    await response.json(),
    alreadyProcessed,
  );
  if (items.length === 0) {
    await finishLocationPostsIngest(supabase, jobId, state);
    return;
  }
  const target = v2BoundLocationPostTargets(
    state.location_post_targets ?? [],
  )[0];
  if (!target) throw new Error("Missing authoritative location-post target");
  for (const item of items) {
    const row = toV2StagingRow(item);
    if (!row) continue;
    v2ApplyAuthoritativeLocation(row, target.location_id);
    const postId = await insertNewPost(supabase, row);
    if (postId !== null) {
      addNewPost(state, postId);
      state.stats.new_posts++;
    }
  }
  state.component_item_count = (state.component_item_count ?? 0) + items.length;
  state.stats.location_posts_received =
    (state.stats.location_posts_received ?? 0) + items.length;
  state.batch_index = (state.batch_index ?? 0) + 1;
  await updateState(supabase, jobId, state);
  await scheduleContinue(jobId, 0);
}

async function finishLocationPostsIngest(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const { error } = await supabase.from("v2_scrape_run_components")
    .update({ item_count: Math.min(3, state.component_item_count ?? 0) })
    .eq("id", state.active_component_id);
  if (error) {
    throw new Error(`Location-post item-count update failed: ${error.message}`);
  }
  state.current_step = "detect";
  state.batch_index = 0;
  await updateState(supabase, jobId, state);
  await scheduleContinue(jobId, 0);
}

async function abortActiveFollowupIfNeeded(state: V2PipelineState) {
  if (state.location_posts_actor_completed || !state.location_posts_run_id) {
    return;
  }
  const token = Deno.env.get("APIFY_TOKEN");
  if (token) await abortActorRun(token, state.location_posts_run_id);
}

async function abortActorRun(token: string, runId: string) {
  await fetch(
    `https://api.apify.com/v2/actor-runs/${runId}/abort?gracefully=true`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    },
  ).catch(() => undefined);
}

async function markComponentFailed(
  supabase: DbClient,
  componentId: string | undefined,
  message: string,
) {
  if (!componentId) return;
  await supabase.from("v2_scrape_run_components").update({
    status: "failed",
    error: message,
    completed_at: new Date().toISOString(),
  }).eq("id", componentId);
}

async function insertNewPost(
  supabase: DbClient,
  row: V2StagingRow,
): Promise<number | null> {
  const { data, error } = await supabase
    .from("v2_scraped_posts")
    .insert(row)
    .select("id")
    .maybeSingle();
  if (!error && data) return data.id;
  // PostgreSQL unique violation means a safe replay, not a new post.
  if (error?.code === "23505") return null;
  throw new Error(
    `Failed to insert post ${row.external_post_id}: ${
      error?.message ?? "unknown error"
    }`,
  );
}

function addNewPost(state: V2PipelineState, id: number) {
  state.new_post_ids ??= [];
  if (!state.new_post_ids.includes(id)) state.new_post_ids.push(id);
}

function addAffectedRestaurant(state: V2PipelineState, id: number) {
  state.affected_restaurant_ids ??= [];
  if (!state.affected_restaurant_ids.includes(id)) {
    state.affected_restaurant_ids.push(id);
  }
}

async function findPlaceRestaurant(
  supabase: DbClient,
  place: V2PlaceCandidate,
): Promise<number | null> {
  if (place.external_id) {
    const { data, error } = await supabase
      .from("v2_restaurant_sources")
      .select("restaurant_id")
      .eq("platform", "instagram")
      .eq("source_type", "location_id")
      .eq("external_id", place.external_id)
      .maybeSingle();
    if (error) throw new Error(`Place source lookup failed: ${error.message}`);
    if (data) return data.restaurant_id;
  }

  const normalized = v2NormalizeName(place.name);
  if (!normalized || place.latitude === null || place.longitude === null) {
    return null;
  }
  const tolerance = 0.002; // roughly 200m in Malaysia; name must also match.
  const { data, error } = await supabase
    .from("v2_restaurants")
    .select("id")
    .eq("normalized_name", normalized)
    .gte("latitude", place.latitude - tolerance)
    .lte("latitude", place.latitude + tolerance)
    .gte("longitude", place.longitude - tolerance)
    .lte("longitude", place.longitude + tolerance)
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(`Nearby place lookup failed: ${error.message}`);
  return data?.id ?? null;
}

async function upsertPlaceRestaurant(
  supabase: DbClient,
  place: V2PlaceCandidate,
  state: V2PipelineState,
): Promise<number | null> {
  const existingId = await findPlaceRestaurant(supabase, place);
  const categories = v2DeriveCategories(place.category, place.name, []);
  let restaurantId = existingId;
  let address = place.address;
  let city = place.city;
  if (existingId && (!address || !city)) {
    const { data, error } = await supabase.from("v2_restaurants")
      .select("address, city").eq("id", existingId).single();
    if (error) throw new Error(`Place address lookup failed: ${error.message}`);
    address ??= data.address;
    city ??= data.city;
  }
  if (
    (!address || !city) && place.latitude !== null && place.longitude !== null
  ) {
    const reverse = await v2ReverseGeocode(place.latitude, place.longitude);
    address ??= reverse?.address ?? null;
    city ??= reverse?.city ?? null;
  }

  if (restaurantId) {
    const patch: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
      last_scraped_at: new Date().toISOString(),
    };
    if (place.name) patch.name = place.name;
    if (address) patch.address = address;
    if (city) patch.city = city;
    if (place.latitude !== null) patch.latitude = place.latitude;
    if (place.longitude !== null) patch.longitude = place.longitude;
    if (place.phone) patch.phone = place.phone;
    if (place.external_id) patch.instagram_location_id = place.external_id;
    if (categories.length) patch.categories = categories;
    const { error } = await supabase.from("v2_restaurants").update(patch).eq(
      "id",
      restaurantId,
    );
    if (error) {
      throw new Error(`Place restaurant update failed: ${error.message}`);
    }
  } else {
    if (!place.name) return null;
    const { data, error } = await supabase.from("v2_restaurants").insert({
      name: place.name,
      normalized_name: v2NormalizeName(place.name),
      address,
      city,
      latitude: place.latitude,
      longitude: place.longitude,
      phone: place.phone,
      instagram_location_id: place.external_id,
      categories,
      verification_confidence: place.external_id ? 0.9 : 0.7,
      is_approved: false,
      last_scraped_at: new Date().toISOString(),
    }).select("id").single();
    if (error || !data) {
      throw new Error(
        `Place restaurant insert failed: ${error?.message ?? "unknown error"}`,
      );
    }
    restaurantId = data.id;
    state.stats.restaurants_created++;
  }

  if (place.external_id) {
    const { error } = await supabase.from("v2_restaurant_sources").upsert({
      restaurant_id: restaurantId,
      platform: "instagram",
      source_type: "location_id",
      external_id: place.external_id,
      name: place.name,
      last_seen_at: new Date().toISOString(),
    }, { onConflict: "platform,source_type,external_id" });
    if (error) throw new Error(`Place source upsert failed: ${error.message}`);
  }
  return restaurantId;
}

async function findRestaurantForPostCandidate(
  supabase: DbClient,
  candidate: {
    name: string | null;
    address: string | null;
    city: string | null;
  },
  latitude: number | null,
  longitude: number | null,
): Promise<number | null> {
  const name = v2NormalizeName(candidate.name);
  if (!name) return null;

  let query = supabase.from("v2_restaurants")
    .select("id, normalized_name, address, city")
    .limit(10);
  if (latitude !== null && longitude !== null) {
    const tolerance = 0.002;
    query = query.gte("latitude", latitude - tolerance)
      .lte("latitude", latitude + tolerance)
      .gte("longitude", longitude - tolerance)
      .lte("longitude", longitude + tolerance);
  } else if (candidate.address) {
    // Without coordinates, the address is mandatory supporting evidence.
    query = query.or(
      `normalized_name.eq.${name},normalized_name.like.${name} %`,
    );
  } else if (candidate.city) {
    // City-only fallback is intentionally exact-name only.
    query = query.eq("normalized_name", name).ilike("city", candidate.city);
  } else {
    return null;
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(`Enrichment semantic dedup failed: ${error.message}`);
  }
  const address = v2NormalizeName(candidate.address);
  const city = v2NormalizeName(candidate.city);
  for (const restaurant of data ?? []) {
    const nameRelation = v2NameRelation(name, restaurant.normalized_name ?? "");
    if (nameRelation === "none") continue;
    if (latitude !== null && longitude !== null) return restaurant.id;

    if (address) {
      const storedAddress = v2NormalizeName(restaurant.address);
      const addressRelation = v2NameRelation(address, storedAddress);
      const cityMatches = !city || city === v2NormalizeName(restaurant.city);
      if (addressRelation !== "none" && cityMatches) return restaurant.id;
    } else if (
      city && nameRelation === "equal" &&
      city === v2NormalizeName(restaurant.city)
    ) {
      return restaurant.id;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Step 3: Detect — filter posts, derive categories
// ---------------------------------------------------------------------------

async function handleDetect(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const runPostIds = state.new_post_ids ?? [];
  if (runPostIds.length === 0) {
    state.current_step = "metrics";
    state.batch_index = 0;
    await updateState(supabase, jobId, state);
    await scheduleContinue(jobId, 0);
    return;
  }
  // Fetch pending posts in batch
  const { data: posts, error: fetchErr } = await supabase
    .from("v2_scraped_posts")
    .select(
      "id, caption, hashtags, location_id, location_name, author_username, likes, comments, views",
    )
    .in("id", runPostIds)
    .eq("status", "pending")
    .limit(BATCH_SIZE);

  if (fetchErr) {
    const retries = (state.retry_count ?? 0) + 1;
    if (retries >= 5) {
      await markFailed(
        supabase,
        jobId,
        state,
        `Detect fetch failed: ${fetchErr.message}`,
      );
      return;
    }
    state.retry_count = retries;
    await updateState(supabase, jobId, state);
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
    return;
  }

  if (!posts || posts.length === 0) {
    // No more pending posts — move to resolve
    state.current_step = "resolve";
    state.batch_index = 0;
    state.retry_count = 0;
    await updateState(supabase, jobId, state);
    console.log(
      `[v2-continue] Job ${jobId}: detect done, ${state.stats.candidates_detected} candidates`,
    );
    await scheduleContinue(jobId, 0);
    return;
  }

  let detected = 0;
  let skipped = 0;

  for (const post of posts) {
    const caption = post.caption ?? "";
    const hashtags: string[] = Array.isArray(post.hashtags)
      ? post.hashtags.map((h: string | { name?: string }) =>
        typeof h === "string" ? h : (h?.name ?? "")
      )
      : [];

    if (v2IsLikelyNotRestaurant(caption, hashtags)) {
      // Mark as skipped
      await supabase
        .from("v2_scraped_posts")
        .update({ status: "skipped" })
        .eq("id", post.id);
      state.stats.posts_skipped++;
      skipped++;
      continue;
    }

    // Derive categories from existing data
    // Mark as candidate_extracted (ready for resolve + enrich)
    await supabase
      .from("v2_scraped_posts")
      .update({
        status: "candidate_extracted",
      })
      .eq("id", post.id);

    state.stats.candidates_detected++;
    detected++;
  }

  state.batch_index = (state.batch_index ?? 0) + 1;
  state.retry_count = 0;
  await updateState(supabase, jobId, state);

  console.log(
    `[v2-continue] Job ${jobId}: detect batch ${state.batch_index}, ` +
      `detected=${detected}, skipped=${skipped} (total detected: ${state.stats.candidates_detected})`,
  );

  await scheduleContinue(jobId, 0);
}

// ---------------------------------------------------------------------------
// Step 4: Resolve — match candidate posts to existing restaurants
// ---------------------------------------------------------------------------

async function handleResolve(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const { data: posts, error: fetchErr } = await supabase
    .from("v2_scraped_posts")
    .select(
      "id, post_url, location_id, author_username, likes, comments, views, caption, hashtags, cover_url",
    )
    .in("id", state.new_post_ids ?? [])
    .eq("status", "candidate_extracted")
    .limit(BATCH_SIZE);

  if (fetchErr) {
    const retries = (state.retry_count ?? 0) + 1;
    if (retries >= 5) {
      await markFailed(
        supabase,
        jobId,
        state,
        `Resolve fetch failed: ${fetchErr.message}`,
      );
      return;
    }
    state.retry_count = retries;
    await updateState(supabase, jobId, state);
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
    return;
  }

  if (!posts || posts.length === 0) {
    // No more candidates to resolve — move to enrich
    state.current_step = "enrich";
    state.batch_index = 0;
    state.retry_count = 0;
    await updateState(supabase, jobId, state);
    console.log(`[v2-continue] Job ${jobId}: resolve done, moving to enrich`);
    await scheduleContinue(jobId, 0);
    return;
  }

  let resolved = 0;

  for (const post of posts) {
    let matchedRestaurantId: number | null = null;

    if (post.post_url) {
      const { data: postSource, error: postSourceError } = await supabase
        .from("v2_restaurant_sources")
        .select("restaurant_id")
        .eq("platform", "instagram")
        .eq("source_type", "post_url")
        .eq("external_id", post.post_url)
        .maybeSingle();
      if (postSourceError) {
        throw new Error(
          `Post source lookup failed: ${postSourceError.message}`,
        );
      }
      matchedRestaurantId = postSource?.restaurant_id ?? null;
    }

    // Try location_id match
    if (!matchedRestaurantId && post.location_id) {
      const { data: locSource, error: locError } = await supabase
        .from("v2_restaurant_sources")
        .select("restaurant_id")
        .eq("platform", "instagram")
        .eq("source_type", "location_id")
        .eq("external_id", post.location_id)
        .maybeSingle();
      if (locError) {
        throw new Error(`Location source lookup failed: ${locError.message}`);
      }

      if (locSource) {
        matchedRestaurantId = locSource.restaurant_id;
      }
    }

    if (matchedRestaurantId) {
      try {
        await linkPostAndRefreshRestaurant(supabase, matchedRestaurantId, post);
        addAffectedRestaurant(state, matchedRestaurantId);
        resolved++;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        await supabase.from("v2_scraped_posts").update({
          status: "failed",
          error: message,
        })
          .eq("id", post.id);
        state.stats.posts_failed++;
      }
    } else {
      // Explicit hand-off avoids repeatedly selecting the same unmatched rows.
      const { error } = await supabase.from("v2_scraped_posts")
        .update({ status: "processing" }).eq("id", post.id);
      if (error) {
        throw new Error(
          `Resolve hand-off failed for post ${post.id}: ${error.message}`,
        );
      }
    }
  }

  state.batch_index = (state.batch_index ?? 0) + 1;
  state.retry_count = 0;
  await updateState(supabase, jobId, state);

  console.log(
    `[v2-continue] Job ${jobId}: resolve batch ${state.batch_index}, ` +
      `resolved=${resolved} (total resolved via match)`,
  );

  await scheduleContinue(jobId, 0);
}

async function linkPostAndRefreshRestaurant(
  supabase: DbClient,
  restaurantId: number,
  post: {
    id: number;
    post_url?: string | null;
    likes?: number;
    comments?: number;
    views?: number;
  },
) {
  const { error: linkError } = await supabase.from("v2_restaurant_social_posts")
    .upsert(
      { restaurant_id: restaurantId, post_id: post.id },
      { onConflict: "restaurant_id,post_id", ignoreDuplicates: true },
    );
  if (linkError) {
    throw new Error(`Social post link failed: ${linkError.message}`);
  }
  if (post.post_url) {
    const { error: sourceError } = await supabase.from("v2_restaurant_sources")
      .upsert({
        restaurant_id: restaurantId,
        platform: "instagram",
        source_type: "post_url",
        external_id: post.post_url,
        last_seen_at: new Date().toISOString(),
      }, { onConflict: "platform,source_type,external_id" });
    if (sourceError) {
      throw new Error(
        `Post URL source registration failed: ${sourceError.message}`,
      );
    }
  }

  const [{ count, error: countError }, { data: restaurant, error: readError }] =
    await Promise.all([
      supabase.from("v2_restaurant_social_posts")
        .select("id", { count: "exact", head: true }).eq(
          "restaurant_id",
          restaurantId,
        ),
      supabase.from("v2_restaurants").select("popularity_score").eq(
        "id",
        restaurantId,
      ).single(),
    ]);
  if (countError || readError) {
    throw new Error(
      `Restaurant aggregate read failed: ${
        countError?.message ?? readError?.message
      }`,
    );
  }
  const popularity = v2PopularityScore(
    post.likes ?? 0,
    post.comments ?? 0,
    post.views ?? 0,
  );
  const { error: updateError } = await supabase.from("v2_restaurants").update({
    source_post_count: count ?? 0,
    popularity_score: Math.max(restaurant?.popularity_score ?? 0, popularity),
    last_scraped_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }).eq("id", restaurantId);
  if (updateError) {
    throw new Error(
      `Restaurant aggregate update failed: ${updateError.message}`,
    );
  }

  const { error: postError } = await supabase.from("v2_scraped_posts")
    .update({ status: "resolved", error: null }).eq("id", post.id);
  if (postError) {
    throw new Error(`Post resolution update failed: ${postError.message}`);
  }
}

// ---------------------------------------------------------------------------
// Step 5: Enrich — LLM extraction, geocoding, new restaurant creation
// ---------------------------------------------------------------------------

async function handleEnrich(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  // Fetch unresolved candidates for LLM enrichment
  const { data: posts, error: fetchErr } = await supabase
    .from("v2_scraped_posts")
    .select(
      "id, post_url, caption, hashtags, author_username, cover_url, location_id, location_name, likes, comments, views",
    )
    .in("id", state.new_post_ids ?? [])
    .eq("status", "processing")
    .limit(BATCH_SIZE);

  if (fetchErr) {
    const retries = (state.retry_count ?? 0) + 1;
    if (retries >= 5) {
      await markFailed(
        supabase,
        jobId,
        state,
        `Enrich fetch failed: ${fetchErr.message}`,
      );
      return;
    }
    state.retry_count = retries;
    await updateState(supabase, jobId, state);
    await scheduleContinue(jobId, APIFY_POLL_DELAY_MS);
    return;
  }

  if (!posts || posts.length === 0) {
    state.current_step = "metrics";
    state.batch_index = 0;
    await updateState(supabase, jobId, state);
    await scheduleContinue(jobId, 0);
    return;
  }

  let enriched = 0;
  let skipped = 0;
  let failed = 0;

  for (const post of posts) {
    try {
      const caption = post.caption ?? "";
      const hashtags: string[] = Array.isArray(post.hashtags)
        ? post.hashtags.map((h: string | { name?: string }) =>
          typeof h === "string" ? h : (h?.name ?? "")
        )
        : [];

      // LLM extraction
      const extraction = await v2ExtractVenue(
        caption,
        hashtags,
        post.author_username,
      );

      if (!extraction.is_restaurant || extraction.confidence < 0.5) {
        await supabase
          .from("v2_scraped_posts")
          .update({ status: "skipped" })
          .eq("id", post.id);
        state.stats.posts_skipped++;
        skipped++;
        continue;
      }

      // Geocode if no location_id already available
      let latitude: number | null = null;
      let longitude: number | null = null;

      if (post.location_id) {
        // We have an IG location — check if we can get coords from the source
        const { data: locSource } = await supabase
          .from("v2_restaurant_sources")
          .select("restaurant_id")
          .eq("platform", "instagram")
          .eq("source_type", "location_id")
          .eq("external_id", post.location_id)
          .maybeSingle();

        if (locSource) {
          await linkPostAndRefreshRestaurant(
            supabase,
            locSource.restaurant_id,
            post,
          );
          addAffectedRestaurant(state, locSource.restaurant_id);
          state.stats.candidates_enriched++;
          enriched++;
          continue;
        }
      }

      // Geocode the venue
      const geo = await v2Geocode(
        extraction.name,
        extraction.address,
        extraction.city,
      );
      if (geo) {
        latitude = geo.latitude;
        longitude = geo.longitude;
      }

      const normalizedName = v2NormalizeName(extraction.name);
      const existingRestaurantId = await findRestaurantForPostCandidate(
        supabase,
        extraction,
        latitude,
        longitude,
      );

      if (existingRestaurantId) {
        await linkPostAndRefreshRestaurant(
          supabase,
          existingRestaurantId,
          post,
        );
        addAffectedRestaurant(state, existingRestaurantId);
        state.stats.candidates_enriched++;
        enriched++;
        continue;
      }

      const { data: newRestaurant, error: insertErr } = await supabase
        .from("v2_restaurants")
        .insert({
          name: extraction.name,
          normalized_name: normalizedName,
          description: extraction.description,
          address: extraction.address,
          city: extraction.city,
          latitude,
          longitude,
          phone: extraction.phone,
          website: extraction.website,
          price_range: extraction.price_range,
          instagram_location_id: post.location_id,
          categories: extraction.categories,
          verification_confidence: extraction.confidence,
          is_approved: false,
          source_post_count: 1,
          popularity_score: v2PopularityScore(
            post.likes ?? 0,
            post.comments ?? 0,
            post.views ?? 0,
          ),
          last_scraped_at: new Date().toISOString(),
        })
        .select("id")
        .single();

      if (insertErr || !newRestaurant) {
        console.error(
          `[v2-continue] Failed to insert restaurant for post ${post.id}:`,
          insertErr?.message,
        );
        await supabase.from("v2_scraped_posts").update({
          status: "failed",
          error: `restaurant_insert_failed: ${
            insertErr?.message ?? "unknown error"
          }`,
        }).eq("id", post.id);
        state.stats.posts_failed++;
        failed++;
        continue;
      }

      const restaurantId = newRestaurant.id;

      // Register sources
      if (post.location_id) {
        const { error: sourceError } = await supabase
          .from("v2_restaurant_sources")
          .upsert(
            {
              restaurant_id: restaurantId,
              platform: "instagram",
              source_type: "location_id",
              external_id: post.location_id,
              last_seen_at: new Date().toISOString(),
            },
            {
              onConflict: "platform,source_type,external_id",
              ignoreDuplicates: true,
            },
          );
        if (sourceError) {
          throw new Error(
            `Location source registration failed: ${sourceError.message}`,
          );
        }
      }

      // Link post to new restaurant
      await linkPostAndRefreshRestaurant(supabase, restaurantId, post);
      const { error: promotedError } = await supabase.from("v2_scraped_posts")
        .update({ status: "promoted" }).eq(
          "id",
          post.id,
        );
      if (promotedError) {
        throw new Error(
          `Post promotion update failed: ${promotedError.message}`,
        );
      }
      addAffectedRestaurant(state, restaurantId);

      state.stats.restaurants_created++;
      state.stats.candidates_enriched++;
      enriched++;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`[v2-continue] Enrich error for post ${post.id}:`, msg);
      await supabase
        .from("v2_scraped_posts")
        .update({ status: "failed", error: msg })
        .eq("id", post.id);
      state.stats.posts_failed++;
      failed++;
    }
  }

  state.batch_index = (state.batch_index ?? 0) + 1;
  state.retry_count = 0;
  await updateState(supabase, jobId, state);

  console.log(
    `[v2-continue] Job ${jobId}: enrich batch ${state.batch_index}, ` +
      `enriched=${enriched}, skipped=${skipped}, failed=${failed} ` +
      `(total restaurants: ${state.stats.restaurants_created})`,
  );

  await scheduleContinue(jobId, 0);
}

// ---------------------------------------------------------------------------
// Step 6: Metrics — recompute social aggregates for affected restaurants
// ---------------------------------------------------------------------------

async function handleMetrics(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  interface MetricPost {
    author_username: string | null;
    likes: number | null;
    comments: number | null;
    views: number | null;
    posted_at: string | null;
    scraped_at: string | null;
    cover_url: string | null;
    caption: string | null;
    hashtags: string[] | null;
  }
  const ids = state.affected_restaurant_ids ?? [];
  const now = Date.now();
  const DAY = 86_400_000;

  for (const restaurantId of ids) {
    const { data: links, error: linkError } = await supabase
      .from("v2_restaurant_social_posts")
      .select("post_id")
      .eq("restaurant_id", restaurantId);
    if (linkError) {
      throw new Error(`Metrics link query failed: ${linkError.message}`);
    }
    const postIds = (links ?? []).map((link) => link.post_id);

    let posts: MetricPost[] = [];
    if (postIds.length > 0) {
      const { data, error } = await supabase.from("v2_scraped_posts")
        .select(
          "author_username, likes, comments, views, posted_at, scraped_at, cover_url, caption, hashtags",
        )
        .in("id", postIds);
      if (error) throw new Error(`Metrics post query failed: ${error.message}`);
      posts = (data ?? []) as MetricPost[];
    }

    const ageDays = (post: MetricPost) => {
      const timestamp = Date.parse(post.posted_at ?? post.scraped_at ?? "");
      return Number.isFinite(timestamp)
        ? Math.max(0, (now - timestamp) / DAY)
        : Infinity;
    };
    const mention7 = posts.filter((post) => ageDays(post) <= 7).length;
    const mention30 = posts.filter((post) => ageDays(post) <= 30).length;
    const mention90 = posts.filter((post) => ageDays(post) <= 90).length;
    const previous7 = posts.filter((post) =>
      ageDays(post) > 7 && ageDays(post) <= 14
    ).length;
    const creators = new Set(
      posts.map((post) => post.author_username).filter(Boolean),
    );
    const totalLikes = posts.reduce((sum, post) => sum + (post.likes ?? 0), 0);
    const totalComments = posts.reduce(
      (sum, post) => sum + (post.comments ?? 0),
      0,
    );
    const totalViews = posts.reduce((sum, post) => sum + (post.views ?? 0), 0);
    const timestamps = posts.map((post) =>
      Date.parse(post.posted_at ?? post.scraped_at ?? "")
    )
      .filter(Number.isFinite);
    const latest = timestamps.length ? Math.max(...timestamps) : null;
    const trend = v2TrendScore({
      mentionsLast7d: mention7,
      mentionsPrev7d: previous7,
      uniqueCreators: creators.size,
      totalMentions: posts.length,
      avgEngagement: posts.length
        ? (totalLikes + totalComments) / posts.length
        : 0,
      daysSinceLastMention: latest === null
        ? 31
        : Math.max(0, (now - latest) / DAY),
    });

    const { error: metricError } = await supabase.from(
      "v2_restaurant_social_metrics",
    ).upsert({
      restaurant_id: restaurantId,
      mention_count_7d: mention7,
      mention_count_30d: mention30,
      mention_count_90d: mention90,
      unique_creator_count: creators.size,
      total_likes: totalLikes,
      total_comments: totalComments,
      total_views: totalViews,
      latest_mention_at: latest === null
        ? null
        : new Date(latest).toISOString(),
      trend_score: trend,
      updated_at: new Date().toISOString(),
    }, { onConflict: "restaurant_id" });
    if (metricError) {
      throw new Error(
        `Metrics upsert failed: ${metricError.message}`,
      );
    }

    const maxPopularity = posts.reduce((max, post) =>
      Math.max(
        max,
        v2PopularityScore(post.likes ?? 0, post.comments ?? 0, post.views ?? 0),
      ), 0);
    const { error: restaurantError } = await supabase.from("v2_restaurants")
      .update({
        source_post_count: posts.length,
        popularity_score: maxPopularity,
        updated_at: new Date().toISOString(),
      }).eq("id", restaurantId);
    if (restaurantError) {
      throw new Error(
        `Metrics restaurant update failed: ${restaurantError.message}`,
      );
    }
    const bestImage = v2SelectBestImageCandidate(
      posts.map((post) => ({
        cover_url: post.cover_url,
        caption: post.caption,
        hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
        likes: post.likes ?? 0,
        comments: post.comments ?? 0,
        posted_at: post.posted_at ?? post.scraped_at,
      })),
      now,
    );
    if (bestImage) {
      await v2PersistPrimaryImage(
        supabase,
        restaurantId,
        bestImage.cover_url,
        bestImage.quality_score,
      );
    }
  }

  state.current_step = "complete";
  await updateState(supabase, jobId, state);
  await scheduleContinue(jobId, 0);
}

// ---------------------------------------------------------------------------
// Step 7: Complete — update v2_scrape_runs, discovery sources, finish
// ---------------------------------------------------------------------------

async function handleComplete(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const duration = state.started_at
    ? Math.round((Date.now() - new Date(state.started_at).getTime()) / 1000)
    : 0;

  state.cost_usd = await settleComponentCosts(supabase, state);

  // Update v2_scrape_runs with totals
  if (state.v2_scrape_run_id) {
    const { error } = await supabase
      .from("v2_scrape_runs")
      .update({
        status: "completed",
        completed_at: new Date().toISOString(),
        posts_received: state.stats.posts_received,
        new_posts: state.stats.new_posts,
        restaurant_candidates: state.stats.candidates_detected,
        new_restaurants: state.stats.restaurants_created,
        cost_usd: state.cost_usd ?? 0,
      })
      .eq("id", state.v2_scrape_run_id);
    if (error) {
      throw new Error(`Scrape-run completion failed: ${error.message}`);
    }
  }

  // Update v2_discovery_sources metrics
  // When multiple sources are combined into one Apify run, divide stats equally
  // to avoid overcounting per-source metrics.
  if (state.source_ids && state.source_ids.length > 0) {
    const now = Date.now();
    const DAY_MS = 24 * 60 * 60 * 1000;
    const sourceCount = state.source_ids.length;
    const resultsPerSource = Math.floor(
      state.stats.posts_received / sourceCount,
    );
    const newPostsPerSource = Math.floor(state.stats.new_posts / sourceCount);
    const candidatesPerSource = Math.floor(
      state.stats.candidates_detected / sourceCount,
    );
    const restaurantsPerSource = Math.floor(
      state.stats.restaurants_created / sourceCount,
    );
    const costPerSource = (state.cost_usd ?? 0) / sourceCount;

    for (const sourceId of state.source_ids) {
      const { data: source, error: sourceReadError } = await supabase
        .from("v2_discovery_sources")
        .select(
          "scrape_count, posts_scraped, new_posts, restaurant_candidates, new_restaurants, verified_restaurants, total_cost_usd",
        )
        .eq("id", sourceId)
        .maybeSingle();
      if (sourceReadError) {
        throw new Error(
          `Discovery-source read failed: ${sourceReadError.message}`,
        );
      }
      if (!source) {
        throw new Error(
          `Discovery source ${sourceId} disappeared during completion`,
        );
      }

      const newScrapeCount = (source.scrape_count ?? 0) + 1;
      const newPostsScraped = (source.posts_scraped ?? 0) + resultsPerSource;
      const newPostsTotal = (source.new_posts ?? 0) + newPostsPerSource;
      const newCandidates = (source.restaurant_candidates ?? 0) +
        candidatesPerSource;
      const newRestaurants = (source.new_restaurants ?? 0) +
        restaurantsPerSource;
      const newCost = (source.total_cost_usd ?? 0) + costPerSource;

      // Yield rate: restaurants / posts scraped
      const yieldRate = newPostsScraped > 0
        ? newRestaurants / newPostsScraped
        : 0;

      // Cost per new restaurant
      const costPerRestaurant = newRestaurants > 0
        ? newCost / newRestaurants
        : 0;

      // Cooldown: 7 days if productive, 14 days if not
      const cooldownMs = state.stats.restaurants_created > 0
        ? 7 * DAY_MS
        : 14 * DAY_MS;
      const nextScrapeAt = nextBusinessHour(now + cooldownMs);

      const sourceUpdate: Record<string, unknown> = {
        scrape_count: newScrapeCount,
        posts_scraped: newPostsScraped,
        new_posts: newPostsTotal,
        restaurant_candidates: newCandidates,
        new_restaurants: newRestaurants,
        total_cost_usd: newCost,
        yield_rate: yieldRate,
        cost_per_new_restaurant: costPerRestaurant,
        last_scraped_at: new Date().toISOString(),
        next_scrape_at: nextScrapeAt,
      };
      if (newScrapeCount >= 5 && yieldRate < 0.005) {
        sourceUpdate.status = "paused";
      }
      const { error: sourceUpdateError } = await supabase
        .from("v2_discovery_sources")
        .update(sourceUpdate)
        .eq("id", sourceId);
      if (sourceUpdateError) {
        throw new Error(
          `Discovery-source update failed: ${sourceUpdateError.message}`,
        );
      }
    }
  }

  // Mark pipeline_jobs as completed
  const { error: completeErr } = await supabase.from("pipeline_jobs").update({
    status: "completed",
    completed_at: new Date().toISOString(),
    duration_seconds: duration,
    result: {
      mode: "v2",
      current_step: "complete",
      dataset_kind: state.dataset_kind,
      result_limit: state.result_limit,
      new_posts: state.stats.new_posts,
      new_restaurants: state.stats.restaurants_created,
      candidates_detected: state.stats.candidates_detected,
      candidates_enriched: state.stats.candidates_enriched,
      skipped: state.stats.posts_skipped,
      failed: state.stats.posts_failed,
      cost_usd: state.cost_usd ?? 0,
      posts_received: state.stats.posts_received,
      places_received: state.stats.places_received ?? 0,
      places_filtered: state.stats.places_filtered ?? 0,
      location_posts_received: state.stats.location_posts_received ?? 0,
      duration_seconds: duration,
    },
  }).eq("id", jobId);

  if (completeErr) {
    throw new Error(`Pipeline-job completion failed: ${completeErr.message}`);
  } else {
    console.log(
      `[v2-continue] Job ${jobId}: completed successfully ` +
        `(cost=$${state.cost_usd ?? 0}, new_posts=${state.stats.new_posts}, ` +
        `restaurants=${state.stats.restaurants_created}, duration=${duration}s)`,
    );
  }
}

async function settleComponentCosts(
  supabase: DbClient,
  state: V2PipelineState,
): Promise<number> {
  const legacyCost = state.cost_usd ?? 0;
  if (!state.v2_scrape_run_id) return legacyCost;
  const { data: components, error } = await supabase
    .from("v2_scrape_run_components")
    .select("id, apify_run_id, cost_usd")
    .eq("scrape_run_id", state.v2_scrape_run_id);
  if (error) throw new Error(`Component cost query failed: ${error.message}`);
  if (!components?.length) {
    return await fetchSettledActorCost(state.apify_run_id, legacyCost);
  }

  const settledCosts: number[] = [];
  for (const component of components) {
    const settled = await fetchSettledActorCost(
      component.apify_run_id,
      Number(component.cost_usd ?? 0),
    );
    const { error: updateError } = await supabase.from(
      "v2_scrape_run_components",
    )
      .update({ cost_usd: settled }).eq("id", component.id);
    if (updateError) {
      throw new Error(`Component cost update failed: ${updateError.message}`);
    }
    settledCosts.push(settled);
  }
  return v2SumComponentCosts(settledCosts);
}

async function fetchSettledActorCost(
  runId: string | undefined,
  current: number,
): Promise<number> {
  const token = Deno.env.get("APIFY_TOKEN");
  if (!runId || !token) return current;

  let settled = current;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(
        `https://api.apify.com/v2/actor-runs/${runId}`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      if (response.ok) {
        const data = await response.json();
        if (typeof data.data?.usageTotalUsd === "number") {
          settled = Math.max(settled, data.data.usageTotalUsd);
          if (settled > 0) return settled;
        }
      }
    } catch (error) {
      console.warn("[v2-continue] Could not refresh settled Apify cost", error);
    }
    if (attempt < 2) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
  return settled;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function updateState(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
) {
  const { error } = await supabase
    .from("pipeline_jobs")
    .update({ result: state })
    .eq("id", jobId);
  if (error) {
    throw new Error(`Failed to update state for ${jobId}: ${error.message}`);
  }
}

async function markFailed(
  supabase: DbClient,
  jobId: string,
  state: V2PipelineState,
  message: string,
) {
  const completedAt = new Date().toISOString();
  // Also update v2_scrape_runs if we have one
  let runError: { message: string } | null = null;
  if (state.v2_scrape_run_id) {
    const result = await supabase
      .from("v2_scrape_runs")
      .update({
        status: "failed",
        error: message,
        completed_at: completedAt,
      })
      .eq("id", state.v2_scrape_run_id);
    runError = result.error;
    await supabase.from("v2_scrape_run_components").update({
      status: "failed",
      error: message,
      completed_at: completedAt,
    }).eq("scrape_run_id", state.v2_scrape_run_id)
      .in("status", ["pending", "running"]);
  }

  const { error } = await supabase.from("pipeline_jobs").update({
    status: "failed",
    completed_at: completedAt,
    error: message,
  }).eq("id", jobId);
  if (error || runError) {
    console.error(
      `[v2-continue] Failed to fully release lifecycle for ${jobId}:`,
      error?.message,
      runError?.message,
    );
  }
}

function scheduleContinue(jobId: string, delayMs: number) {
  EdgeRuntime.waitUntil(
    new Promise((r) => setTimeout(r, delayMs))
      .then(() =>
        fetch(
          `${Deno.env.get("SUPABASE_URL")}/functions/v1/v2-pipeline-continue`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${
                Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
              }`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ job_id: jobId }),
          },
        ).then(async (resp) => {
          if (!resp.ok) {
            const text = await resp.text();
            throw new Error(`Chain call failed (${resp.status}): ${text}`);
          }
        })
      )
      .catch(async (err) => {
        console.error(`[v2-continue] Chain call error for ${jobId}:`, err);
        try {
          const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
          );
          const { data: job } = await supabase.from("pipeline_jobs")
            .select("result").eq("id", jobId).maybeSingle();
          const state =
            (job?.result ?? { stats: emptyStats() }) as V2PipelineState;
          if (!state.v2_scrape_run_id) {
            const { data: activeRun } = await supabase.from("v2_scrape_runs")
              .select("id").in("status", ["pending", "running"])
              .order("created_at", { ascending: false }).limit(1).maybeSingle();
            state.v2_scrape_run_id = activeRun?.id;
          }
          const token = Deno.env.get("APIFY_TOKEN");
          const activeActorRunId =
            state.current_step === "location_posts_scrape"
              ? state.location_posts_run_id
              : (state.current_step === "scrape"
                ? state.apify_run_id
                : undefined);
          if (token && activeActorRunId) {
            await abortActorRun(token, activeActorRunId);
          }
          await markFailed(
            supabase,
            jobId,
            state,
            `Pipeline chain interrupted: ${err}`,
          );
        } catch {
          console.error(
            `[v2-continue] Could not mark ${jobId} as failed after chain error`,
          );
        }
      }),
  );
}

async function failOnlyActiveScrapeRun(supabase: DbClient, message: string) {
  const { data: activeRun } = await supabase.from("v2_scrape_runs")
    .select("id").in("status", ["pending", "running"])
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (!activeRun) return;
  const { error } = await supabase.from("v2_scrape_runs").update({
    status: "failed",
    error: message,
    completed_at: new Date().toISOString(),
  }).eq("id", activeRun.id);
  if (error) {
    console.error(
      `[v2-continue] Failed to release orphan run: ${error.message}`,
    );
  }
}

function emptyStats(): V2PipelineState["stats"] {
  return {
    posts_received: 0,
    new_posts: 0,
    candidates_detected: 0,
    candidates_enriched: 0,
    restaurants_created: 0,
    posts_skipped: 0,
    posts_failed: 0,
  };
}
