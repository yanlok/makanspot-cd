// ============================================================================
// upload_dataset.mjs
// ----------------------------------------------------------------------------
// Thin uploader: reads a local Apify scraper export (JSON array) and POSTs it
// to the `ingest-scraped-posts` Edge Function, which lands the rows in the
// public.scraped_posts staging table. Run once per new dataset.
//
// Usage (PowerShell):
//   $env:SUPABASE_ANON_KEY="sb_publishable_..."
//   node scripts/upload_dataset.mjs "C:\path\to\dataset_tiktok-scraper.json"
//
// Optional env:
//   SUPABASE_PROJECT_REF  (default: npmdrgpypkozdjtiplmf)
//   FUNCTIONS_BASE_URL    (overrides the derived https://<ref>.functions.supabase.co)
//   BATCH_SIZE            (default: 50 records per request)
// ============================================================================

import { readFile } from "node:fs/promises";

const projectRef = process.env.SUPABASE_PROJECT_REF ?? "npmdrgpypkozdjtiplmf";
const baseUrl = process.env.FUNCTIONS_BASE_URL ??
  `https://${projectRef}.functions.supabase.co`;
const anonKey = process.env.SUPABASE_ANON_KEY;
const batchSize = Number(process.env.BATCH_SIZE ?? 50);

const filePath = process.argv[2];

if (!filePath) {
  console.error("Usage: node scripts/upload_dataset.mjs <path-to-dataset.json>");
  process.exit(1);
}
if (!anonKey) {
  console.error("Set SUPABASE_ANON_KEY (the project's publishable/anon key) first.");
  process.exit(1);
}

const raw = await readFile(filePath, "utf8");
const parsed = JSON.parse(raw);
const records = Array.isArray(parsed) ? parsed : parsed.items ?? [];

if (!Array.isArray(records) || records.length === 0) {
  console.error("No records found in the file.");
  process.exit(1);
}

console.log(`Loaded ${records.length} records from ${filePath}`);
console.log(`Uploading to ${baseUrl}/ingest-scraped-posts in batches of ${batchSize}...`);

let totals = { received: 0, inserted: 0, skipped: 0 };

for (let i = 0; i < records.length; i += batchSize) {
  const batch = records.slice(i, i + batchSize);
  const resp = await fetch(`${baseUrl}/ingest-scraped-posts`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${anonKey}`,
      "apikey": anonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(batch),
  });

  const text = await resp.text();
  if (!resp.ok) {
    console.error(`Batch ${i / batchSize + 1} failed (${resp.status}): ${text}`);
    process.exit(1);
  }

  const result = JSON.parse(text);
  totals.received += result.received ?? 0;
  totals.inserted += result.inserted ?? 0;
  totals.skipped += result.skipped ?? 0;
  console.log(`  Batch ${i / batchSize + 1}: ${JSON.stringify(result)}`);
}

console.log("Done.", totals);
console.log("Next: invoke `enrich-scraped-posts` to promote rows into restaurants.");
