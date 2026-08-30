/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// auto-run
// ----------------------------------------------------------------------------
// Orchestrates sequential query processing for the data scraper pipeline.
// Creates auto-run sessions, picks eligible queries, triggers pipeline runs,
// and chains to itself for continuous processing until stopped or limits hit.
//
// POST body: {
//   action: "start" | "pause" | "resume" | "stop" | "continue",
//   auto_run_id?: string,       -- required for pause/resume/stop/continue
//   config?: {
//     results_per_query?: number, -- 20-40, default 30
//     max_queries?: number,       -- default 10
//     cost_limit_usd?: number     -- default 5.00
//   }
// }
//
// Response: { auto_run_id, status, ... }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
type DbClient = SupabaseClient<any, any, any, any, any>;

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest, isServiceRoleRequest } from "../_shared/auth.ts";
import { fetchWithTimeout } from "../_shared/http.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface AutoRunConfig {
  results_per_query: number;
  max_queries: number;
  cost_limit_usd: number;
}

interface AutoRunRow {
  id: string;
  status: string;
  config: AutoRunConfig;
  current_query_source_id: number | null;
  queries_completed: number;
  new_restaurants: number;
  existing_matched: number;
  skipped_no_image: number;
  failed_candidates: number;
  total_cost_usd: number;
  current_scrape_run_id: string | null;
  stop_reason: string | null;
  started_at: string | null;
  completed_at: string | null;
}

interface DiscoverySource {
  id: number;
  source_type: string;
  source_value: string;
  priority_score: number | null;
  next_scrape_at: string | null;
  status: string;
}

interface ScrapeRunResult {
  new_restaurants?: number;
  existing_restaurants_matched?: number;
  restaurants_no_image?: number;
  posts_failed?: number;
  failed?: number;
  cost_usd?: number;
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

  const action = body.action as string;
  if (!action) {
    return jsonResponse({ error: "Missing action" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Internal service-to-service calls (pipeline-continue → auto-run-continue)
  // use the service-role key. External admin calls use isAdminRequest.
  const isInternal = await isServiceRoleRequest(req);
  if (!isInternal && !(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }

  switch (action) {
    case "start":
      return handleStart(supabase, body);
    case "pause":
      return handlePause(supabase, body);
    case "resume":
      return handleResume(supabase, body);
    case "stop":
      return handleStop(supabase, body);
    case "continue":
      // Internal chain endpoint — called by pipeline-continue or self-chain
      return handleContinue(supabase, body);
    default:
      return jsonResponse({ error: `Unknown action: ${action}` }, 400);
  }
});

// ---------------------------------------------------------------------------
// Action: start — create a new auto-run session and kick off the first query
// ---------------------------------------------------------------------------

async function handleStart(
  supabase: DbClient,
  body: Record<string, unknown>,
) {
  // Guard: no active auto-runs
  const { data: activeRun } = await supabase
    .from("auto_runs")
    .select("id")
    .in("status", ["pending", "running", "paused"])
    .limit(1)
    .maybeSingle();
  if (activeRun) {
    return jsonResponse({
      error: "auto_run_already_active",
      message: "An auto-run is already in progress. Stop it first.",
    }, 409);
  }

  // Guard: no active scrape runs
  const { data: activeScrape } = await supabase
    .from("scrape_runs")
    .select("id")
    .in("status", ["pending", "running"])
    .limit(1)
    .maybeSingle();
  if (activeScrape) {
    return jsonResponse({
      error: "scrape_run_already_active",
      message: "A scrape run is already in progress. Wait for it to finish.",
    }, 409);
  }

  const configInput = (body.config as Record<string, unknown>) ?? {};
  const config: AutoRunConfig = {
    results_per_query: clampInt(
      configInput.results_per_query as number | undefined,
      30,
      20,
      40,
    ),
    max_queries: clampInt(configInput.max_queries as number | undefined, 10, 1, 100),
    cost_limit_usd: clampFloat(
      configInput.cost_limit_usd as number | undefined,
      5.0,
      0,
      100,
    ),
  };

  // Create auto-run session
  const { data: autoRun, error: insertErr } = await supabase
    .from("auto_runs")
    .insert({
      status: "running",
      config,
      started_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (insertErr || !autoRun) {
    return jsonResponse(
      { error: `Failed to create auto-run: ${insertErr?.message}` },
      500,
    );
  }

  console.log(
    `[auto-run] Started ${autoRun.id}: config=${JSON.stringify(config)}`,
  );

  // Pick first source and trigger pipeline
  const result = await triggerNextQuery(supabase, autoRun.id, config);
  if (result.error) {
    // Mark auto-run as failed if we can't start the first query
    await supabase.from("auto_runs").update({
      status: "failed",
      stop_reason: result.error,
      completed_at: new Date().toISOString(),
    }).eq("id", autoRun.id);
    return jsonResponse({ error: result.error }, 409);
  }

  return jsonResponse({
    auto_run_id: autoRun.id,
    status: "running",
    source_id: result.sourceId,
  });
}

// ---------------------------------------------------------------------------
// Action: pause — finish current query but don't start the next one
// ---------------------------------------------------------------------------

async function handlePause(
  supabase: DbClient,
  body: Record<string, unknown>,
) {
  const autoRunId = body.auto_run_id as string;
  if (!autoRunId) {
    return jsonResponse({ error: "Missing auto_run_id" }, 400);
  }

  const { data: autoRun, error: readErr } = await supabase
    .from("auto_runs")
    .select("id, status")
    .eq("id", autoRunId)
    .single();

  if (readErr || !autoRun) {
    return jsonResponse({ error: "Auto-run not found" }, 404);
  }
  if (autoRun.status !== "running") {
    return jsonResponse({
      error: `Cannot pause: auto-run is ${autoRun.status}`,
    }, 400);
  }

  const { error } = await supabase
    .from("auto_runs")
    .update({ status: "paused" })
    .eq("id", autoRunId);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  console.log(`[auto-run] Paused ${autoRunId}`);
  return jsonResponse({ auto_run_id: autoRunId, status: "paused" });
}

// ---------------------------------------------------------------------------
// Action: resume — continue processing from where we left off
// ---------------------------------------------------------------------------

async function handleResume(
  supabase: DbClient,
  body: Record<string, unknown>,
) {
  const autoRunId = body.auto_run_id as string;
  if (!autoRunId) {
    return jsonResponse({ error: "Missing auto_run_id" }, 400);
  }

  const { data: autoRun, error: readErr } = await supabase
    .from("auto_runs")
    .select("id, status")
    .eq("id", autoRunId)
    .single();

  if (readErr || !autoRun) {
    return jsonResponse({ error: "Auto-run not found" }, 404);
  }
  if (autoRun.status !== "paused") {
    return jsonResponse({
      error: `Cannot resume: auto-run is ${autoRun.status}`,
    }, 400);
  }

  // Guard: no active scrape runs
  const { data: activeScrape } = await supabase
    .from("scrape_runs")
    .select("id")
    .in("status", ["pending", "running"])
    .limit(1)
    .maybeSingle();
  if (activeScrape) {
    return jsonResponse({
      error: "scrape_run_already_active",
      message: "A scrape run is already in progress.",
    }, 409);
  }

  const { error } = await supabase
    .from("auto_runs")
    .update({ status: "running" })
    .eq("id", autoRunId);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  // Re-read config and chain to continue
  const { data: updated } = await supabase
    .from("auto_runs")
    .select("config")
    .eq("id", autoRunId)
    .single();

  const config = (updated?.config as AutoRunConfig) ?? {
    results_per_query: 30,
    max_queries: 10,
    cost_limit_usd: 5.0,
  };

  scheduleAutoRunContinue(autoRunId);

  console.log(`[auto-run] Resumed ${autoRunId}`);
  return jsonResponse({ auto_run_id: autoRunId, status: "running" });
}

// ---------------------------------------------------------------------------
// Action: stop — cancel current run and mark session as stopped
// ---------------------------------------------------------------------------

async function handleStop(
  supabase: DbClient,
  body: Record<string, unknown>,
) {
  const autoRunId = body.auto_run_id as string;
  if (!autoRunId) {
    return jsonResponse({ error: "Missing auto_run_id" }, 400);
  }

  const { data: autoRun, error: readErr } = await supabase
    .from("auto_runs")
    .select("id, status, current_scrape_run_id")
    .eq("id", autoRunId)
    .single();

  if (readErr || !autoRun) {
    return jsonResponse({ error: "Auto-run not found" }, 404);
  }
  if (
    autoRun.status === "completed" || autoRun.status === "failed" ||
    autoRun.status === "stopped"
  ) {
    return jsonResponse({
      error: `Auto-run already ${autoRun.status}`,
    }, 400);
  }

  // Cancel active scrape run if one exists
  if (autoRun.current_scrape_run_id) {
    await cancelScrapeRun(supabase, autoRun.current_scrape_run_id);
  }

  const { error } = await supabase.from("auto_runs").update({
    status: "stopped",
    stop_reason: "Stopped by admin",
    completed_at: new Date().toISOString(),
    current_scrape_run_id: null,
  }).eq("id", autoRunId);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  console.log(`[auto-run] Stopped ${autoRunId}`);
  return jsonResponse({ auto_run_id: autoRunId, status: "stopped" });
}

// ---------------------------------------------------------------------------
// Action: continue — called after a scrape run completes; picks next query
// ---------------------------------------------------------------------------

async function handleContinue(
  supabase: DbClient,
  body: Record<string, unknown>,
) {
  const autoRunId = body.auto_run_id as string;
  if (!autoRunId) {
    return jsonResponse({ error: "Missing auto_run_id" }, 400);
  }

  const { data: autoRun, error: readErr } = await supabase
    .from("auto_runs")
    .select("*")
    .eq("id", autoRunId)
    .single();

  if (readErr || !autoRun) {
    console.error(`[auto-run] Auto-run ${autoRunId} not found`);
    return jsonResponse({ error: "Auto-run not found" }, 404);
  }

  const run = autoRun as AutoRunRow;

  // Only continue if running (not paused, stopped, completed, failed)
  if (run.status !== "running") {
    console.log(
      `[auto-run] ${autoRunId} is ${run.status} — stopping continue chain`,
    );
    return jsonResponse({ ok: true, skipped: true });
  }

  const config = run.config;

  // --- Idempotency guard: atomically claim the continue slot ---
  // Only one invocation should proceed. If current_scrape_run_id is already
  // null, another invocation already processed this completion.
  if (run.current_scrape_run_id) {
    const { error: claimErr } = await supabase
      .from("auto_runs")
      .update({ current_scrape_run_id: null })
      .eq("id", autoRunId)
      .eq("current_scrape_run_id", run.current_scrape_run_id);
    if (claimErr) {
      // Another invocation already claimed this slot
      console.log(
        `[auto-run] ${autoRunId}: continue already claimed — skipping`,
      );
      return jsonResponse({ ok: true, skipped: true, reason: "already_claimed" });
    }
    // We won the claim — accumulate stats
    await accumulateScrapeRunStats(supabase, {
      ...run,
      current_scrape_run_id: run.current_scrape_run_id,
    });
  }

  // --- Re-read auto-run state to get fresh counters ---
  const { data: freshRun } = await supabase
    .from("auto_runs")
    .select("queries_completed, new_restaurants, existing_matched, skipped_no_image, failed_candidates, total_cost_usd")
    .eq("id", autoRunId)
    .single();
  const queriesCompleted = (freshRun?.queries_completed ?? run.queries_completed) + 1;
  const totalCostUsd = freshRun?.total_cost_usd ?? run.total_cost_usd;

  if (queriesCompleted >= config.max_queries) {
    await supabase.from("auto_runs").update({
      status: "completed",
      queries_completed: queriesCompleted,
      stop_reason: `Reached max queries (${config.max_queries})`,
      completed_at: new Date().toISOString(),
      current_scrape_run_id: null,
    }).eq("id", autoRunId);
    console.log(
      `[auto-run] ${autoRunId}: completed — reached max queries`,
    );
    scheduleEnrichment(autoRunId);
    return jsonResponse({ ok: true, completed: true });
  }

  if (totalCostUsd >= config.cost_limit_usd) {
    await supabase.from("auto_runs").update({
      status: "completed",
      queries_completed: queriesCompleted,
      stop_reason: `Reached cost limit ($${config.cost_limit_usd})`,
      completed_at: new Date().toISOString(),
      current_scrape_run_id: null,
    }).eq("id", autoRunId);
    console.log(
      `[auto-run] ${autoRunId}: completed — reached cost limit`,
    );
    scheduleEnrichment(autoRunId);
    return jsonResponse({ ok: true, completed: true });
  }

  // --- Pick next query ---
  const result = await triggerNextQuery(supabase, autoRunId, config);
  if (result.error) {
    await supabase.from("auto_runs").update({
      status: "completed",
      queries_completed: queriesCompleted,
      stop_reason: result.error,
      completed_at: new Date().toISOString(),
      current_scrape_run_id: null,
    }).eq("id", autoRunId);
    console.log(
      `[auto-run] ${autoRunId}: completed — ${result.error}`,
    );
    scheduleEnrichment(autoRunId);
    return jsonResponse({ ok: true, completed: true, reason: result.error });
  }

  // Update queries_completed (use fresh values to avoid overwriting concurrent writes)
  await supabase.from("auto_runs").update({
    queries_completed,
    current_query_source_id: result.sourceId,
    new_restaurants: freshRun?.new_restaurants ?? run.new_restaurants,
    existing_matched: freshRun?.existing_matched ?? run.existing_matched,
    skipped_no_image: freshRun?.skipped_no_image ?? run.skipped_no_image,
    failed_candidates: freshRun?.failed_candidates ?? run.failed_candidates,
    total_cost_usd: freshRun?.total_cost_usd ?? run.total_cost_usd,
  }).eq("id", autoRunId);

  console.log(
    `[auto-run] ${autoRunId}: query ${queriesCompleted + 1}/${config.max_queries}, ` +
      `source=${result.sourceId}`,
  );

  return jsonResponse({
    ok: true,
    query_index: queriesCompleted + 1,
    source_id: result.sourceId,
  });
}

// ---------------------------------------------------------------------------
// Core: pick next eligible source and trigger a pipeline run
// ---------------------------------------------------------------------------

async function triggerNextQuery(
  supabase: DbClient,
  autoRunId: string,
  config: AutoRunConfig,
): Promise<{ sourceId?: number; error?: string }> {
  // Pick the highest-priority active source that is due
  const { data: source, error: sourceErr } = await supabase
    .from("discovery_sources")
    .select(
      "id, source_type, source_value, priority_score, next_scrape_at, status",
    )
    .eq("status", "active")
    .lte("next_scrape_at", new Date().toISOString())
    .order("priority_score", { ascending: false, nullsFirst: false })
    .limit(1)
    .maybeSingle();

  if (sourceErr) {
    return { error: `Failed to load sources: ${sourceErr.message}` };
  }
  if (!source) {
    return { error: "No eligible discovery sources remaining" };
  }

  const src = source as DiscoverySource;

  // Classify source type and determine actor
  let actorId: string;
  let actorInput: Record<string, unknown>;
  let datasetKind: "place" | "post";

  if (src.source_type === "hashtag") {
    actorId = "apify%2Finstagram-hashtag-scraper";
    actorInput = {
      hashtags: [src.source_value.replace(/^#+/, "")],
      resultsLimit: config.results_per_query,
      searchType: "hashtag",
      addParentData: true,
      timeoutSecs: 300,
      memoryMbytes: 4096,
    };
    datasetKind = "post";
  } else if (
    src.source_type === "search_query" || src.source_type === "automation"
  ) {
    actorId = "apify%2Finstagram-search-scraper";
    actorInput = {
      search: src.source_value,
      searchType: "place",
      searchLimit: config.results_per_query,
      addParentData: true,
      timeoutSecs: 300,
      memoryMbytes: 4096,
    };
    datasetKind = "place";
  } else {
    return {
      error: `Source type "${src.source_type}" is not supported by Auto Run`,
    };
  }

  // Create scrape run linked to auto-run
  const { data: scrapeRun, error: runErr } = await supabase
    .from("scrape_runs")
    .insert({
      source_id: src.id,
      auto_run_id: autoRunId,
      status: "pending",
    })
    .select("id")
    .single();

  if (runErr || !scrapeRun) {
    return {
      error: `Failed to create scrape run: ${runErr?.message}`,
    };
  }

  // Create discovery component
  const { data: component, error: compErr } = await supabase
    .from("scrape_run_components")
    .insert({
      scrape_run_id: scrapeRun.id,
      component_type: "discovery",
      status: "pending",
      actor_id: actorId.replace("%2F", "/"),
    })
    .select("id")
    .single();

  if (compErr || !component) {
    await failAutoRunScrapeRun(
      supabase,
      scrapeRun.id,
      `Failed to create component: ${compErr?.message}`,
    );
    return {
      error: `Failed to create component: ${compErr?.message}`,
    };
  }

  // Start Apify actor
  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) {
    await failAutoRunScrapeRun(supabase, scrapeRun.id, "APIFY_TOKEN not configured");
    return { error: "APIFY_TOKEN not configured" };
  }

  let apifyRunId: string | null = null;
  try {
    const startResp = await fetchWithTimeout(
      `https://api.apify.com/v2/acts/${actorId}/runs`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(actorInput),
      },
      20_000,
    );
    if (!startResp.ok) {
      throw new Error(
        `Apify start failed (${startResp.status}): ${await startResp.text()}`,
      );
    }
    const startData = await startResp.json();
    apifyRunId = startData.data?.id ?? null;
    if (!apifyRunId) throw new Error("No run ID returned from Apify");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await failAutoRunScrapeRun(supabase, scrapeRun.id, message);
    return { error: message };
  }

  // Initialize pipeline state
  const startedAt = new Date().toISOString();
  const pipelineState = {
    scrape_run_id: scrapeRun.id,
    apify_run_id: apifyRunId,
    active_component_id: component.id,
    source_ids: [src.id],
    dataset_kind: datasetKind,
    result_limit: config.results_per_query,
    current_step: "scrape",
    batch_index: 0,
    started_at: startedAt,
    stats: {
      posts_received: 0,
      new_posts: 0,
      candidates_detected: 0,
      candidates_enriched: 0,
      restaurants_created: 0,
      existing_restaurants_matched: 0,
      restaurants_no_image: 0,
      posts_skipped: 0,
      posts_failed: 0,
    },
  };

  const [runUpdate, compUpdate] = await Promise.all([
    supabase.from("scrape_runs").update({
      status: "running",
      started_at: startedAt,
      apify_run_id: apifyRunId,
      result: pipelineState,
    }).eq("id", scrapeRun.id),
    supabase.from("scrape_run_components").update({
      status: "running",
      apify_run_id: apifyRunId,
      started_at: startedAt,
    }).eq("id", component.id),
  ]);

  if (runUpdate.error || compUpdate.error) {
    await abortApifyRun(token, apifyRunId);
    const msg = runUpdate.error?.message ?? compUpdate.error?.message;
    await failAutoRunScrapeRun(supabase, scrapeRun.id, msg);
    return { error: `Failed to initialize: ${msg}` };
  }

  // Link the scrape run back to the auto-run session (atomic claim)
  const { error: linkErr } = await supabase
    .from("auto_runs")
    .update({ current_scrape_run_id: scrapeRun.id })
    .eq("id", autoRunId)
    .is("current_scrape_run_id", null);
  if (linkErr) {
    // Another invocation already claimed the slot — abort this scrape run
    await failAutoRunScrapeRun(supabase, scrapeRun.id, "Concurrent claim conflict");
    return { error: "Concurrent continue already in progress" };
  }

  // Chain to pipeline-continue
  EdgeRuntime.waitUntil(
    fetchWithTimeout(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/pipeline-continue`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ job_id: scrapeRun.id }),
      },
      45_000,
    ).then(async (resp) => {
      if (!resp.ok) {
        const text = await resp.text();
        await abortApifyRun(token, apifyRunId);
        await failAutoRunScrapeRun(
          supabase,
          scrapeRun.id,
          `Chain failed (${resp.status}): ${text}`,
        );
      }
    }).catch(async (error) => {
      await abortApifyRun(token, apifyRunId);
      await failAutoRunScrapeRun(
        supabase,
        scrapeRun.id,
        `Chain error: ${error instanceof Error ? error.message : String(error)}`,
      );
    }),
  );

  return { sourceId: src.id };
}

// ---------------------------------------------------------------------------
// Accumulate stats from a completed scrape run into the auto-run totals
// ---------------------------------------------------------------------------

async function accumulateScrapeRunStats(
  supabase: DbClient,
  autoRun: AutoRunRow,
): Promise<number> {
  if (!autoRun.current_scrape_run_id) return autoRun.total_cost_usd;

  const { data: scrapeRun } = await supabase
    .from("scrape_runs")
    .select("result, cost_usd")
    .eq("id", autoRun.current_scrape_run_id)
    .maybeSingle();

  if (!scrapeRun) return autoRun.total_cost_usd;

  const result = (scrapeRun.result as ScrapeRunResult) ?? {};
  const costUsd = Number(scrapeRun.cost_usd ?? 0);

  const failedCount = result.posts_failed ?? result.failed ?? 0;

  await supabase.from("auto_runs").update({
    new_restaurants:
      autoRun.new_restaurants + (result.new_restaurants ?? 0),
    existing_matched:
      autoRun.existing_matched +
      (result.existing_restaurants_matched ?? 0),
    skipped_no_image:
      autoRun.skipped_no_image + (result.restaurants_no_image ?? 0),
    failed_candidates:
      autoRun.failed_candidates + failedCount,
    total_cost_usd: autoRun.total_cost_usd + costUsd,
    current_scrape_run_id: null,
  }).eq("id", autoRun.id);

  return autoRun.total_cost_usd + costUsd;
}

// ---------------------------------------------------------------------------
// Cancel a scrape run (aborts Apify actors and marks as failed)
// ---------------------------------------------------------------------------

async function cancelScrapeRun(supabase: DbClient, runId: string) {
  const { data: scrapeRun } = await supabase
    .from("scrape_runs")
    .select("result, status")
    .eq("id", runId)
    .maybeSingle();

  if (!scrapeRun || scrapeRun.status !== "running") return;

  const state = scrapeRun.result as Record<string, unknown> | null;
  const token = Deno.env.get("APIFY_TOKEN");

  if (token && state) {
    const apifyRunId = state.apify_run_id as string | undefined;
    const locationRunId = state.location_posts_run_id as string | undefined;
    if (apifyRunId) await abortApifyRun(token, apifyRunId);
    if (locationRunId) await abortApifyRun(token, locationRunId);
  }

  await supabase.from("scrape_runs").update({
    status: "failed",
    error: "Cancelled by auto-run",
    completed_at: new Date().toISOString(),
  }).eq("id", runId);

  await supabase.from("scrape_run_components").update({
    status: "failed",
    error: "Cancelled by auto-run",
    completed_at: new Date().toISOString(),
  }).eq("scrape_run_id", runId).in("status", ["pending", "running"]);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function scheduleEnrichment(autoRunId: string) {
  // Fire-and-forget: enrich newly created restaurants after auto-run completes.
  // Finds restaurants with missing address/phone/hours and uses LLM to fill them.
  EdgeRuntime.waitUntil(
    fetch(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/enrich-restaurants`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
          }`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ batch_size: 20 }),
      },
    ).then(async (resp) => {
      if (resp.ok) {
        const data = await resp.json();
        console.log(
          `[auto-run] Enrichment complete for ${autoRunId}: ${data.enriched} enriched, ${data.skipped} skipped`,
        );
      } else {
        console.error(
          `[auto-run] Enrichment failed for ${autoRunId}: ${resp.status}`,
        );
      }
    }).catch((err) => {
      console.error(`[auto-run] Enrichment error for ${autoRunId}:`, err);
    }),
  );
}

function scheduleAutoRunContinue(autoRunId: string) {
  EdgeRuntime.waitUntil(
    new Promise((r) => setTimeout(r, 1000))
      .then(() =>
        fetch(
          `${Deno.env.get("SUPABASE_URL")}/functions/v1/auto-run`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${
                Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
              }`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ action: "continue", auto_run_id: autoRunId }),
          },
        )
      )
      .catch((err) => {
        console.error(`[auto-run] Continue chain error for ${autoRunId}:`, err);
      }),
  );
}

async function failAutoRunScrapeRun(
  supabase: DbClient,
  runId: string,
  message: string,
) {
  const completedAt = new Date().toISOString();
  await supabase.from("scrape_runs").update({
    status: "failed",
    error: message,
    completed_at: completedAt,
  }).eq("id", runId);
  await supabase.from("scrape_run_components").update({
    status: "failed",
    error: message,
    completed_at: completedAt,
  }).eq("scrape_run_id", runId).in("status", ["pending", "running"]);
}

async function abortApifyRun(token: string, runId: string | null) {
  if (!runId) return;
  try {
    await fetchWithTimeout(
      `https://api.apify.com/v2/actor-runs/${runId}/abort?gracefully=true`,
      { method: "POST", headers: { "Authorization": `Bearer ${token}` } },
      10_000,
    );
  } catch {
    // Best-effort abort
  }
}

function clampInt(
  value: number | undefined,
  fallback: number,
  min: number,
  max: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(value)));
}

function clampFloat(
  value: number | undefined,
  fallback: number,
  min: number,
  max: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(min, Math.min(max, value));
}
