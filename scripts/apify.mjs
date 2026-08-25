// ============================================================================
// apify.mjs
// ----------------------------------------------------------------------------
// Lightweight Apify API helper for running actors and fetching results.
// Used by run_pipeline.mjs to pull Instagram data directly from Apify.
//
// Config via env:
//   APIFY_TOKEN  — your Apify API token (required)
//
// Usage:
//   import { runAndFetch } from "./apify.mjs";
//   const items = await runAndFetch("apify/instagram-scraper", { ...input });
// ============================================================================

const APIFY_BASE = "https://api.apify.com/v2";

/**
 * Run an Apify actor and wait for it to finish.
 * Returns the run object (with defaultDatasetId for fetching results).
 *
 * @param {string} actorId — e.g. "apify/instagram-scraper"
 * @param {object} input — actor input configuration
 * @param {object} [opts] — { timeoutSecs, memoryMbytes, token }
 * @returns {Promise<object>} — the completed run object
 */
export async function runActor(actorId, input, opts = {}) {
  const token = opts.token ?? process.env.APIFY_TOKEN;
  if (!token) throw new Error("APIFY_TOKEN env variable is required");

  const timeoutSecs = opts.timeoutSecs ?? 300; // 5 min default
  const memoryMbytes = opts.memoryMbytes ?? 4096;

  // Start the actor run
  const startUrl = `${APIFY_BASE}/acts/${encodeURIComponent(actorId)}/runs`;
  const startResp = await fetch(startUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({
      ...input,
      timeoutSecs,
      memoryMbytes,
    }),
  });

  if (!startResp.ok) {
    const err = await startResp.text();
    throw new Error(`Failed to start actor ${actorId}: ${startResp.status} ${err}`);
  }

  const startData = await startResp.json();
  const runId = startData.data?.id;
  if (!runId) throw new Error("No run ID returned from Apify");

  console.log(`    Actor ${actorId} started (run: ${runId})`);

  // Poll until the run finishes
  const runUrl = `${APIFY_BASE}/actor-runs/${runId}`;
  const deadline = Date.now() + timeoutSecs * 1000;
  let run;

  while (Date.now() < deadline) {
    await sleep(3000); // poll every 3 seconds

    const pollResp = await fetch(runUrl, {
      headers: { "Authorization": `Bearer ${token}` },
    });
    if (!pollResp.ok) continue;

    const pollData = await pollResp.json();
    run = pollData.data;
    const status = run?.status;

    if (status === "SUCCEEDED") {
      console.log(`    Actor finished — ${run.stats?.totalRequests ?? "?"} requests`);
      return run;
    }
    if (status === "FAILED" || status === "ABORTED" || status === "TIMED-OUT") {
      throw new Error(`Actor run ${status}: ${run?.statusMessage ?? "unknown error"}`);
    }
    // still running (READY, RUNNING, etc.) — keep polling
  }

  throw new Error(`Actor run timed out after ${timeoutSecs}s`);
}

/**
 * Fetch all items from an Apify dataset.
 *
 * @param {string} datasetId
 * @param {object} [opts] — { token }
 * @returns {Promise<object[]>}
 */
export async function fetchDatasetItems(datasetId, opts = {}) {
  const token = opts.token ?? process.env.APIFY_TOKEN;
  if (!token) throw new Error("APIFY_TOKEN env variable is required");

  const url = new URL(`${APIFY_BASE}/datasets/${datasetId}/items`);
  url.searchParams.set("format", "json");

  const resp = await fetch(url.toString(), {
    headers: { "Authorization": `Bearer ${token}` },
  });

  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Failed to fetch dataset ${datasetId}: ${resp.status} ${err}`);
  }

  return resp.json();
}

/**
 * Run an actor and return its dataset items (convenience wrapper).
 *
 * @param {string} actorId
 * @param {object} input
 * @param {object} [opts]
 * @returns {Promise<object[]>}
 */
export async function runAndFetch(actorId, input, opts = {}) {
  const run = await runActor(actorId, input, opts);
  const datasetId = run.defaultDatasetId;
  if (!datasetId) throw new Error("No dataset ID in completed run");
  return fetchDatasetItems(datasetId, opts);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
