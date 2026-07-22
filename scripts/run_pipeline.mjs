// ============================================================================
// run_pipeline.mjs
// ----------------------------------------------------------------------------
// One-command TikTok -> restaurants pipeline. No AI needed to run it.
//
//   1. Picks up a JSON dataset (drop it in the /datasets folder, or pass a path)
//   2. Ingests it into the scraped_posts staging table (with a progress bar)
//   3. Enriches + promotes rows into restaurants (LLM -> geocode -> Places photo
//      -> Supabase Storage -> categories), looping until everything is done
//
// Usage (from the project root):
//   node scripts/run_pipeline.mjs                 # newest .json in /datasets
//   node scripts/run_pipeline.mjs "C:\path\file.json"
//   node scripts/run_pipeline.mjs --enrich-only   # skip ingest, just process
//   node scripts/run_pipeline.mjs --reprocess     # rebuild all restaurants first
//
// Or just double-click run_pipeline.cmd in the project root.
//
// Config via env (all optional — sensible defaults baked in):
//   SUPABASE_ANON_KEY   publishable key (defaults to this project's public key)
//   SUPABASE_PROJECT_REF, FUNCTIONS_BASE_URL, DATASETS_DIR
//   BATCH_SIZE (ingest, default 50), ENRICH_LIMIT (default 15),
//   MIN_CONFIDENCE (default 0.5)
// ============================================================================

import { readFile, readdir, stat } from "node:fs/promises";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const projectRef = process.env.SUPABASE_PROJECT_REF ?? "npmdrgpypkozdjtiplmf";
const baseUrl = process.env.FUNCTIONS_BASE_URL ??
  `https://${projectRef}.functions.supabase.co`;
// The publishable/anon key is a PUBLIC key (safe to embed, same one the app
// ships with). Override with SUPABASE_ANON_KEY if the project's key changes.
const anonKey = process.env.SUPABASE_ANON_KEY ??
  "sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH";
const batchSize = Number(process.env.BATCH_SIZE ?? 50);
const enrichLimit = Number(process.env.ENRICH_LIMIT ?? 15);
const minConfidence = Number(process.env.MIN_CONFIDENCE ?? 0.5);

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(scriptDir, "..");
const datasetsDir = process.env.DATASETS_DIR ?? join(projectRoot, "datasets");

const args = process.argv.slice(2);
const enrichOnly = args.includes("--enrich-only");
const doReprocess = args.includes("--reprocess");
const doBackfillPlaces = args.includes("--backfill-places");
const pathArg = args.find((a) => !a.startsWith("--"));

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------
async function postJson(fnPath, body) {
  const resp = await fetch(`${baseUrl}/${fnPath}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${anonKey}`,
      "apikey": anonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`${fnPath} failed (${resp.status}): ${text}`);
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

/** Rewrites a single terminal line with a progress bar. */
function drawBar(label, current, total) {
  const pct = total > 0 ? Math.min(100, Math.round((current / total) * 100)) : 100;
  const width = 24;
  const filled = Math.round((pct / 100) * width);
  const bar = "#".repeat(filled) + "-".repeat(width - filled);
  const line = `  ${label.padEnd(10)} [${bar}] ${String(pct).padStart(3)}% ` +
    `(${current}/${total})`;
  process.stdout.write(`\r${line}   `);
}
function endBar() {
  process.stdout.write("\n");
}

/** Newest *.json file in the datasets folder, or null when there are none. */
async function findNewestDataset() {
  let entries;
  try {
    entries = await readdir(datasetsDir);
  } catch {
    return null; // folder does not exist yet
  }
  const jsons = entries.filter((f) => extname(f).toLowerCase() === ".json");
  if (jsons.length === 0) return null;
  const withTimes = await Promise.all(
    jsons.map(async (f) => {
      const full = join(datasetsDir, f);
      const s = await stat(full);
      return { full, mtime: s.mtimeMs };
    }),
  );
  withTimes.sort((a, b) => b.mtime - a.mtime);
  return withTimes[0].full;
}

// ---------------------------------------------------------------------------
// Phase 1 — ingest a dataset into staging
// ---------------------------------------------------------------------------
async function ingest(filePath) {
  const raw = await readFile(filePath, "utf8");
  const parsed = JSON.parse(raw);
  const records = Array.isArray(parsed) ? parsed : parsed.items ?? [];
  if (!Array.isArray(records) || records.length === 0) {
    throw new Error(`No records found in ${filePath}`);
  }

  console.log(`\n[1/2] Ingesting ${records.length} records from:`);
  console.log(`      ${filePath}`);

  const totals = { received: 0, inserted: 0, skipped: 0 };
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const result = await postJson("ingest-scraped-posts", batch);
    totals.received += result.received ?? 0;
    totals.inserted += result.inserted ?? 0;
    totals.skipped += result.skipped ?? 0;
    drawBar("Ingesting", Math.min(i + batch.length, records.length), records.length);
  }
  endBar();
  console.log(
    `      new: ${totals.inserted}   already-had: ${totals.skipped}   ` +
      `total seen: ${totals.received}`,
  );
}

// ---------------------------------------------------------------------------
// Phase 2 — enrich + promote pending rows into restaurants
// ---------------------------------------------------------------------------
async function enrich() {
  console.log(`\n[2/2] Enriching pending posts (LLM -> geocode -> photo -> DB)...`);

  const status = await postJson("enrich-scraped-posts", { action: "status" });
  const total = status?.counts?.pending ?? 0;
  if (total === 0) {
    console.log("      Nothing pending — everything is already processed.");
    return;
  }

  const totals = { promoted: 0, merged: 0, skipped: 0, failed: 0 };
  let done = 0;
  drawBar("Enriching", 0, total);
  // Loop until a batch returns 0 processed (queue drained).
  for (;;) {
    const r = await postJson("enrich-scraped-posts", {
      limit: enrichLimit,
      minConfidence,
    });
    const processed = r.processed ?? 0;
    if (processed === 0) break;
    totals.promoted += r.promoted ?? 0;
    totals.merged += r.merged ?? 0;
    totals.skipped += r.skipped ?? 0;
    totals.failed += r.failed ?? 0;
    done = Math.min(done + processed, total);
    drawBar("Enriching", done, total);
  }
  drawBar("Enriching", total, total);
  endBar();
  console.log(
    `      new restaurants: ${totals.promoted}   merged duplicates: ` +
      `${totals.merged}   not-a-venue: ${totals.skipped}   needs-admin: ` +
      `${totals.failed}`,
  );
}

// ---------------------------------------------------------------------------
// Phase 3 — backfill Places data for existing restaurants
// ---------------------------------------------------------------------------
async function backfillPlaces() {
  console.log(`\n[3/3] Backfilling Google Places data for existing restaurants...`);

  let totals = { backfilled: 0, skipped: 0 };
  let done = 0;
  drawBar("Backfill", 0, 1); // indeterminate start

  for (;;) {
    const r = await postJson("enrich-scraped-posts", {
      action: "backfill-places",
      limit: 25,
    });
    const backfilled = r.backfilled ?? 0;
    if (backfilled === 0) {
      if (r.message) console.log(`\n      ${r.message}`);
      break;
    }
    totals.backfilled += backfilled;
    totals.skipped += (r.skipped ?? 0);
    done += backfilled;
    drawBar("Backfill", done, done + (r.skipped ?? 0));
  }
  endBar();
  console.log(
    `      restaurants updated: ${totals.backfilled}   skipped: ${totals.skipped}`,
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log("MakanSpot pipeline");
  console.log(`  target: ${baseUrl}`);

  // Standalone backfill: just fill Places data, skip ingest + enrich
  if (doBackfillPlaces && !doReprocess && !enrichOnly && !pathArg) {
    await backfillPlaces();
    console.log("\nDone.");
    return;
  }

  if (doReprocess) {
    console.log("\n[0]   Reprocess: deleting scraped-sourced restaurants + " +
      "resetting rows to pending...");
    const r = await postJson("enrich-scraped-posts", { action: "reprocess" });
    console.log(
      `      reset ${r.reset_to_pending ?? 0} rows, deleted ` +
        `${r.deleted_restaurants ?? 0} restaurants.`,
    );
  }

  if (!enrichOnly) {
    const file = pathArg ?? (await findNewestDataset());
    if (file) {
      await ingest(file);
    } else {
      console.log(
        `\n[1/2] No dataset file given and none found in:\n      ${datasetsDir}` +
          `\n      Skipping ingest — will just enrich whatever is pending.` +
          `\n      (Drop a *.json export in that folder, then re-run.)`,
      );
    }
  }

  await enrich();

  // After enrichment, optionally backfill Places data for existing restaurants
  if (doBackfillPlaces) {
    await backfillPlaces();
  }

  console.log("\nDone. New restaurants land as is_approved = false — approve them " +
    "in the admin dashboard.");
}

main().catch((err) => {
  process.stdout.write("\n");
  console.error("ERROR:", err.message ?? err);
  process.exit(1);
});
