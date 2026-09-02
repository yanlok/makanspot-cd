/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// trigger-pipeline
// ----------------------------------------------------------------------------
// Entry point for the scraping pipeline. Selects discovery sources,
// starts an Apify run, creates tracking rows, and hands off to
// pipeline-continue for batched processing.
//
// POST body: { source_ids?: number[], result_limit?: number }
// Response:  { job_id, run_id, status: "pending" }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
type DbClient = SupabaseClient<any, any, any, any, any>;
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest } from "../_shared/auth.ts";
import { fetchWithTimeout } from "../_shared/http.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface DiscoverySource {
  id: number;
  source_type: string;
  source_value: string;
  priority_score: number | null;
  next_scrape_at: string | null;
  last_scraped_at?: string | null;
  status: string;
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

  const sourceIds = Array.isArray(body.source_ids)
    ? body.source_ids.filter((id): id is number =>
      Number.isInteger(id) && id > 0
    )
    : undefined;
  // Production keeps the existing 20-result default. Manual verification can
  // send 1-3 to keep Apify spend deliberately small.
  const requestedLimit = typeof body.result_limit === "number"
    ? body.result_limit
    : 20;
  const resultLimit = Math.max(1, Math.min(20, Math.trunc(requestedLimit)));

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  if (!(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }

  // --- Guard: no active scrape_runs ---
  const { data: activeRun, error: activeRunError } = await supabase
    .from("scrape_runs")
    .select("id")
    .in("status", ["pending", "running"])
    .limit(1)
    .maybeSingle();
  if (activeRunError) {
    return jsonResponse({
      error: `Failed to check scrape-run lock: ${activeRunError.message}`,
    }, 500);
  }

  if (activeRun) {
    return jsonResponse({
      error: "run_already_active",
      message: "A scrape run is already in progress. Wait for it to finish.",
    }, 409);
  }

  // --- Pick sources ---
  let sources: DiscoverySource[] = [];

  if (sourceIds && sourceIds.length > 0) {
    const { data, error } = await supabase
      .from("discovery_sources")
      .select(
        "id, source_type, source_value, priority_score, next_scrape_at, status",
      )
      .eq("id", sourceIds[0])
      .eq("status", "active");

    if (error) {
      console.error(
        "[trigger] Failed to load specified sources:",
        error.message,
      );
      return jsonResponse(
        { error: `Failed to load sources: ${error.message}` },
        500,
      );
    }
    sources = (data ?? []) as DiscoverySource[];
  } else {
    // priority_score is now recomputed after every run from real
    // yield/cost data (see _shared/discovery-priority.ts). Break ties by
    // staleness so equally-ranked sources still rotate.
    const { data, error } = await supabase
      .from("discovery_sources")
      .select(
        "id, source_type, source_value, priority_score, next_scrape_at, last_scraped_at, status",
      )
      .eq("status", "active")
      .lte("next_scrape_at", new Date().toISOString())
      .order("priority_score", { ascending: false, nullsFirst: false })
      .order("last_scraped_at", { ascending: true, nullsFirst: true })
      .limit(1);

    if (error) {
      console.error("[trigger] Failed to load due sources:", error.message);
      return jsonResponse(
        { error: `Failed to load sources: ${error.message}` },
        500,
      );
    }
    sources = (data ?? []) as DiscoverySource[];
  }

  if (sources.length === 0) {
    return jsonResponse({
      error: "no_sources_due",
      message: "No discovery sources are due for scraping. Try again later.",
    }, 409);
  }

  console.log(
    `[trigger] Selected ${sources.length} sources:`,
    sources.map((s) => `${s.source_type}:${s.source_value}`),
  );

  // --- Classify sources by Apify actor ---
  const hashtagSources = sources.filter((s) => s.source_type === "hashtag");
  const searchSources = sources.filter((s) =>
    s.source_type === "search_query" || s.source_type === "automation"
  );
  const skippedSources = sources.filter(
    (s) => s.source_type === "account" || s.source_type === "location",
  );

  if (skippedSources.length > 0) {
    console.log(
      `[trigger] Skipping ${skippedSources.length} account/location sources (not yet supported)`,
      skippedSources.map((s) => `${s.source_type}:${s.source_value}`),
    );
  }

  // We start ONE Apify run: combine hashtags or use search.
  // If both hashtag and search sources are selected, prefer hashtags (they
  // yield more posts per dollar) and log the search sources for a future run.
  let actorRunInput: Record<string, unknown> | null = null;
  let actorId: string | null = null;
  let runSourceIds: number[] = [];
  let datasetKind: "place" | "post";

  if (hashtagSources.length > 0) {
    actorId = "apify%2Finstagram-hashtag-scraper";
    actorRunInput = {
      hashtags: hashtagSources.map((s) => s.source_value.replace(/^#+/, "")),
      resultsLimit: resultLimit,
      searchType: "hashtag",
      addParentData: true,
      timeoutSecs: 300,
      memoryMbytes: 4096,
    };
    runSourceIds = hashtagSources.map((s) => s.id);
    datasetKind = "post";

    if (searchSources.length > 0) {
      console.log(
        `[trigger] ${searchSources.length} search sources deferred to next run`,
      );
    }
  } else if (searchSources.length > 0) {
    actorId = "apify%2Finstagram-search-scraper";
    actorRunInput = {
      search: searchSources.map((s) => s.source_value).join(","),
      searchType: "place",
      searchLimit: resultLimit,
      timeoutSecs: 300,
      memoryMbytes: 4096,
    };
    runSourceIds = searchSources.map((s) => s.id);
    datasetKind = "place";
  } else {
    // Only unsupported source types selected — nothing to run
    return jsonResponse({
      error: "no_runnable_sources",
      message:
        "Selected sources are not supported by the current scraper actors.",
    }, 409);
  }

  // Create the scrape run. The active-run check above serves as the
  // concurrency guard.
  const { data: scrapeRun, error: runInsertErr } = await supabase
    .from("scrape_runs")
    .insert({
      source_id: runSourceIds[0],
      status: "pending",
    })
    .select("id")
    .single();

  if (runInsertErr || !scrapeRun) {
    if (runInsertErr?.code === "23505") {
      return jsonResponse({
        error: "run_already_active",
        message: "A scrape run is already in progress. Wait for it to finish.",
      }, 409);
    }
    const message = `Failed to create pending scrape run: ${
      runInsertErr?.message ?? "unknown error"
    }`;
    return jsonResponse({
      error: message,
    }, 500);
  }

  const { data: component, error: componentError } = await supabase
    .from("scrape_run_components").insert({
      scrape_run_id: scrapeRun.id,
      component_type: "discovery",
      status: "pending",
      actor_id: actorId?.replace("%2F", "/"),
    }).select("id").single();
  if (componentError || !component) {
    const message = `Failed to create discovery component: ${
      componentError?.message ?? "unknown error"
    }`;
    await failTriggerLifecycle(supabase, scrapeRun.id, message);
    return jsonResponse({ error: message }, 500);
  }

  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) {
    await failTriggerLifecycle(
      supabase,
      scrapeRun.id,
      "APIFY_TOKEN not configured",
    );
    return jsonResponse({ error: "APIFY_TOKEN not configured" }, 500);
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
        body: JSON.stringify(actorRunInput),
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
    await failTriggerLifecycle(supabase, scrapeRun.id, message);
    return jsonResponse({ error: message }, 502);
  }

  const startedAt = new Date().toISOString();
  const result = {
    scrape_run_id: scrapeRun.id,
    apify_run_id: apifyRunId,
    active_component_id: component.id,
    source_ids: runSourceIds,
    dataset_kind: datasetKind,
    result_limit: resultLimit,
    current_step: "scrape",
    batch_index: 0,
    started_at: startedAt,
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

  const [runStart, componentStart] = await Promise.all([
    supabase.from("scrape_runs").update({
      status: "running",
      started_at: startedAt,
      apify_run_id: apifyRunId,
      result,
    }).eq("id", scrapeRun.id),
    supabase.from("scrape_run_components").update({
      status: "running",
      apify_run_id: apifyRunId,
      started_at: startedAt,
    }).eq("id", component.id),
  ]);
  if (runStart.error || componentStart.error) {
    await abortApifyRun(token, apifyRunId);
    await failTriggerLifecycle(
      supabase,
      scrapeRun.id,
      `Initial running-state write failed: ${
        runStart.error?.message ?? componentStart.error?.message
      }`,
    );
    return jsonResponse({ error: "Failed to initialize pipeline state" }, 500);
  }

  // Chain to pipeline-continue
  EdgeRuntime.waitUntil(
    fetchWithTimeout(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/pipeline-continue`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
          }`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ job_id: scrapeRun.id }),
      },
      // Cold starts plus the worker's first bounded Apify poll can exceed the
      // ordinary external-request timeout. Give this internal handoff one
      // processing-budget window before treating it as interrupted.
      45_000,
    ).then(async (resp) => {
      if (!resp.ok) {
        const text = await resp.text();
        await abortApifyRun(token, apifyRunId);
        await failTriggerLifecycle(
          supabase,
          scrapeRun.id,
          `Initial chain failed (${resp.status}): ${text}`,
        );
      }
    }).catch(async (error) => {
      await abortApifyRun(token, apifyRunId);
      await failTriggerLifecycle(
        supabase,
        scrapeRun.id,
        `Initial chain error: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }),
  );

  return jsonResponse({
    job_id: scrapeRun.id,
    run_id: scrapeRun.id,
    status: "pending",
  });
});

async function abortApifyRun(token: string, runId: string | null) {
  if (!runId) return;
  try {
    const response = await fetchWithTimeout(
      `https://api.apify.com/v2/actor-runs/${runId}/abort?gracefully=true`,
      { method: "POST", headers: { "Authorization": `Bearer ${token}` } },
      10_000,
    );
    if (!response.ok) {
      console.error(
        `[trigger] Apify abort failed (${response.status}): ${await response
          .text()}`,
      );
    }
  } catch (error) {
    console.error(`[trigger] Apify abort error:`, error);
  }
}

async function failTriggerLifecycle(
  supabase: DbClient,
  runId: string,
  message: string,
) {
  const completedAt = new Date().toISOString();
  const [runResult] = await Promise.all([
    supabase.from("scrape_runs").update({
      status: "failed",
      error: message,
      completed_at: completedAt,
    }).eq("id", runId),
  ]);
  const { error: componentError } = await supabase
    .from("scrape_run_components")
    .update({ status: "failed", error: message, completed_at: completedAt })
    .eq("scrape_run_id", runId)
    .in("status", ["pending", "running"]);
  if (runResult.error || componentError) {
    console.error(
      `[${runId}] Lifecycle cleanup incomplete:`,
      runResult.error?.message,
      componentError?.message,
    );
  }
}
