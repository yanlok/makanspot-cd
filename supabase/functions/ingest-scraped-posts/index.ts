/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// ingest-scraped-posts
// ----------------------------------------------------------------------------
// Accepts a raw Apify scraper export (a JSON array of records, OR
// { items: [...] }) and upserts each record into public.scraped_posts,
// deduplicating on web_video_url. Runs with the service_role key so it can
// write to the RLS-protected staging table.
//
// POST body: ApifyRecord[]  |  { items: ApifyRecord[] }
// Response:  { received, inserted, skipped }
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { ApifyRecord, toStagingRow } from "../_shared/apify.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let payload: unknown;
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const records: ApifyRecord[] = Array.isArray(payload)
    ? payload as ApifyRecord[]
    : (payload as { items?: ApifyRecord[] })?.items ?? [];

  if (!Array.isArray(records) || records.length === 0) {
    return jsonResponse({ error: "Expected a non-empty array of records" }, 400);
  }

  // Map + drop records without a usable dedup key, and de-dupe within the batch.
  const seen = new Set<string>();
  const rows = [];
  for (const rec of records) {
    const row = toStagingRow(rec);
    if (!row) continue;
    if (seen.has(row.web_video_url)) continue;
    seen.add(row.web_video_url);
    rows.push(row);
  }

  if (rows.length === 0) {
    return jsonResponse({ received: records.length, inserted: 0, skipped: records.length });
  }

  // Upsert on the unique web_video_url. ignoreDuplicates keeps previously
  // enriched rows untouched on re-import.
  const { data, error } = await supabase
    .from("scraped_posts")
    .upsert(rows, { onConflict: "web_video_url", ignoreDuplicates: true })
    .select("id");

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  const inserted = data?.length ?? 0;
  return jsonResponse({
    received: records.length,
    inserted,
    skipped: records.length - inserted,
  });
});
