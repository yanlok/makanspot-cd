/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// pipeline-status
// ----------------------------------------------------------------------------
// Read-only status endpoint for the pipeline. Returns aggregate stats from
// scraped_posts, active/recent scrape_runs, and discovery source health.
//
// POST body: { run_id?: string, job_id?: string }
//
// Response:
// {
//   status: "running" | "idle" | "completed" | "failed",
//   active_run: { ... },
//   stats: {
//     total_posts: N,
//     pending: N,
//     promoted: N,
//     skipped: N,
//     failed: N,
//     total_restaurants: N,
//     total_cost_usd: N
//   },
//   discovery_sources: [ ... ],
//   recent_runs: [ ... ]
// }
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest } from "../_shared/auth.ts";

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

  // After the pipeline_jobs removal, job_id is the scrape_run_id.
  const runId = (body.run_id as string | undefined) ??
    (body.job_id as string | undefined);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  if (!(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }

  // --- Parallel queries ---

  // Active/recent scrape runs (or specific run if run_id provided)
  const [activeRunResult, recentRunsResult, specificRunResult] = await Promise
    .all([
      runId
        ? supabase.from("scrape_runs").select("*").eq("id", runId)
          .maybeSingle()
        : supabase
          .from("scrape_runs")
          .select(
            "id, source_id, status, started_at, completed_at, posts_received, new_posts, restaurant_candidates, new_restaurants, verified_restaurants, cost_usd, error, created_at",
          )
          .in("status", ["running", "pending"])
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle(),
      supabase
        .from("scrape_runs")
        .select(
          "id, source_id, status, started_at, completed_at, posts_received, new_posts, restaurant_candidates, new_restaurants, cost_usd, error, created_at",
        )
        .in("status", ["completed", "failed"])
        .order("created_at", { ascending: false })
        .limit(10),
      // If run_id provided, also fetch it separately for the response
      runId
        ? supabase
          .from("scrape_runs")
          .select(
            "id, source_id, status, started_at, completed_at, posts_received, new_posts, restaurant_candidates, new_restaurants, cost_usd, error, created_at",
          )
          .eq("id", runId)
          .maybeSingle()
        : Promise.resolve({ data: null }),
    ]);

  // Aggregate stats from scraped_posts
  const statusCounts = await Promise.all(
    [
      "pending",
      "candidate_extracted",
      "promoted",
      "skipped",
      "failed",
      "resolved",
    ].map(
      async (status) => {
        const { count } = await supabase
          .from("scraped_posts")
          .select("id", { count: "exact", head: true })
          .eq("status", status);
        return [status, count ?? 0] as const;
      },
    ),
  );

  const counts: Record<string, number> = Object.fromEntries(statusCounts);

  // Total restaurants
  const { count: totalRestaurants } = await supabase
    .from("restaurants")
    .select("id", { count: "exact", head: true });

  // Total cost from recent runs
  const totalCost = (recentRunsResult.data ?? []).reduce(
    (sum, run) => sum + (run.cost_usd ?? 0),
    0,
  );

  // Discovery sources summary
  const { data: sources } = await supabase
    .from("discovery_sources")
    .select(
      "id, source_type, source_value, status, scrape_count, posts_scraped, new_posts, restaurant_candidates, new_restaurants, verified_restaurants, total_cost_usd, yield_rate, cost_per_new_restaurant, priority_score, last_scraped_at, next_scrape_at",
    )
    .order("priority_score", { ascending: false, nullsFirst: false });

  // Determine top-level status
  let status = "idle";
  const activeRun = activeRunResult.data;
  const specificRun = specificRunResult.data;

  if (runId && specificRun) {
    // Specific run requested — use its status directly
    status =
      specificRun.status === "running" || specificRun.status === "pending"
        ? "running"
        : specificRun.status;
  } else if (activeRun) {
    status = "running";
  }

  const totalPosts = (counts.pending ?? 0) + (counts.candidate_extracted ?? 0) +
    (counts.promoted ?? 0) + (counts.skipped ?? 0) + (counts.failed ?? 0) +
    (counts.resolved ?? 0);

  console.log(
    `[pipeline-status] runId=${
      runId ?? "(none)"
    } → status=${status}, ` +
      `posts=${totalPosts}, restaurants=${totalRestaurants ?? 0}`,
  );

  return jsonResponse({
    status,
    active_run: activeRun ?? null,
    specific_run: specificRun ?? null,
    stats: {
      total_posts: totalPosts,
      pending: counts.pending ?? 0,
      candidate_extracted: counts.candidate_extracted ?? 0,
      promoted: counts.promoted ?? 0,
      skipped: counts.skipped ?? 0,
      failed: counts.failed ?? 0,
      resolved: counts.resolved ?? 0,
      total_restaurants: totalRestaurants ?? 0,
      total_cost_usd: totalCost,
    },
    discovery_sources: sources ?? [],
    recent_runs: (recentRunsResult.data ?? []).map((run) => ({
      id: run.id,
      source_id: run.source_id,
      status: run.status,
      started_at: run.started_at,
      completed_at: run.completed_at,
      posts_received: run.posts_received,
      new_posts: run.new_posts,
      restaurant_candidates: run.restaurant_candidates,
      new_restaurants: run.new_restaurants,
      cost_usd: run.cost_usd,
      error: run.error,
    })),
  });
});
