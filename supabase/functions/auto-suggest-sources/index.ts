/// <reference path="../_shared/deno.d.ts" />
// ============================================================================
// auto-suggest-sources
// ----------------------------------------------------------------------------
// Analyzes existing discovery source yield data and uses an LLM to suggest
// new search queries. Called at the end of each pipeline run.
//
// POST body: {} (no input required)
// Response:  { suggestions_added: number, suggestions: [...] }
// ============================================================================

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchWithTimeout } from "../_shared/http.ts";
import { isServiceRoleRequest } from "../_shared/auth.ts";
type DbClient = SupabaseClient<any, any, any, any, any>;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SourceRow {
  id: number;
  source_type: string;
  source_value: string;
  area: string | null;
  yield_rate: number | null;
  new_restaurants: number | null;
  posts_scraped: number | null;
  scrape_count: number | null;
}

interface Suggestion {
  query: string;
  area: string;
  reason: string;
}

const MAX_SUGGESTIONS = 5;
const MAX_ACTIVE_SOURCES = 50;
const MAX_NEW_PER_CYCLE = 5;

/** Canonical comparison key shared by manual and AI-generated searches. */
export function normalizeSearchQuery(value: string): string {
  return value
    .trim()
    .replace(/^#+\s*/, "")
    .replace(/\s+/g, " ")
    .toLocaleLowerCase("en");
}

const SUGGESTION_SYSTEM_PROMPT =
  `You are a data analyst for a Malaysian restaurant discovery app called MakanSpot.
Your job is to suggest new Instagram search queries to find restaurants.

You will receive a table of existing discovery sources and their performance metrics.
Based on these results, suggest ${MAX_SUGGESTIONS} NEW search queries that could find
similar restaurants.

Rules:
- Focus on Malaysian food areas (KL, PJ, Subang, Bangsar, TTDI, Kepong, Damansara, Cheras, Ampang, etc.)
- Use search_query type (Instagram place searches work best)
- Mix cuisines: Malay, Chinese, Indian, Mamak, Western, Japanese, Korean, Thai
- Include area-specific queries (e.g., "nasi lemak Bangsar", "cafe TTDI")
- Do NOT repeat existing queries listed in the input
- Each query should be a realistic Instagram search term
- Keep queries short and natural (1-4 words)
- Prioritize areas and cuisines that have shown good yield rates

Return strict JSON:
{
  "suggestions": [
    {
      "query": "search term",
      "area": "location name",
      "reason": "brief explanation"
    }
  ]
}`;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

if (import.meta.main) Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405);
  }
  if (!(await isServiceRoleRequest(req))) {
    return jsonResponse({ error: "service_role_required" }, 403);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const result = await suggestNewSources(supabase);
    return jsonResponse(result);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[auto-suggest] Failed:", msg);
    return jsonResponse({ error: msg }, 500);
  }
});

// ---------------------------------------------------------------------------
// Core logic (also callable from pipeline-continue)
// ---------------------------------------------------------------------------

export async function suggestNewSources(
  supabase: DbClient,
): Promise<{ suggestions_added: number; suggestions: Suggestion[] }> {
  // Check active source cap
  const { count: activeCount, error: countError } = await supabase
    .from("discovery_sources")
    .select("id", { count: "exact", head: true })
    .eq("status", "active");

  if (countError) {
    throw new Error(`Active source count failed: ${countError.message}`);
  }

  if ((activeCount ?? 0) >= MAX_ACTIVE_SOURCES) {
    console.log(
      `[auto-suggest] Skipped: ${activeCount} active sources (cap: ${MAX_ACTIVE_SOURCES})`,
    );
    return { suggestions_added: 0, suggestions: [] };
  }

  // Fetch top-performing sources with yield data
  const { data: sources, error: sourcesError } = await supabase
    .from("discovery_sources")
    .select(
      "id, source_type, source_value, area, yield_rate, new_restaurants, posts_scraped, scrape_count",
    )
    .gt("scrape_count", 0)
    .order("yield_rate", { ascending: false, nullsFirst: false })
    .limit(20);

  if (sourcesError) {
    throw new Error(`Source query failed: ${sourcesError.message}`);
  }

  if (!sources || sources.length === 0) {
    console.log("[auto-suggest] No scraped sources yet, skipping");
    return { suggestions_added: 0, suggestions: [] };
  }

  // Duplicate protection must cover every manual and AI-generated search,
  // not only the top-performing rows included in the LLM prompt.
  const { data: querySources, error: querySourcesError } = await supabase
    .from("discovery_sources")
    .select("source_value")
    .in("source_type", ["search_query", "automation"]);
  if (querySourcesError) {
    throw new Error(
      `Existing query lookup failed: ${querySourcesError.message}`,
    );
  }
  const knownQueryKeys = new Set(
    (querySources ?? []).map((source) =>
      normalizeSearchQuery(source.source_value ?? "")
    ).filter(Boolean),
  );

  // Build context for LLM
  const existingQueries = sources.map((s) => s.source_value);
  const sourceTable = sources.map((s) =>
    `| ${s.source_type} | ${s.source_value} | ${s.area ?? "—"} | ${
      ((s.yield_rate ?? 0) * 100).toFixed(1)
    }% | ${s.new_restaurants ?? 0} | ${s.posts_scraped ?? 0} |`
  ).join("\n");

  const userContent =
    `Existing sources (type | query | area | yield | restaurants | posts):
| --- | --- | --- | --- | --- | --- |
${sourceTable}

Existing queries to avoid: ${existingQueries.join(", ")}

Suggest ${MAX_SUGGESTIONS} new search queries.`;

  // Call LLM
  const suggestions = await callLLM(userContent);

  if (suggestions.length === 0) {
    console.log("[auto-suggest] LLM returned no suggestions");
    return { suggestions_added: 0, suggestions: [] };
  }

  // Filter out duplicates and insert
  let added = 0;
  const results: Suggestion[] = [];
  const remainingCapacity = Math.max(
    0,
    MAX_ACTIVE_SOURCES - (activeCount ?? 0),
  );
  const insertLimit = Math.min(MAX_NEW_PER_CYCLE, remainingCapacity);

  for (const suggestion of suggestions.slice(0, MAX_NEW_PER_CYCLE)) {
    if (added >= insertLimit) break;
    const query = suggestion.query.trim().replace(/^#+\s*/, "")
      .replace(/\s+/g, " ");
    const queryKey = normalizeSearchQuery(query);
    if (!queryKey) continue;

    if (knownQueryKeys.has(queryKey)) {
      console.log(`[auto-suggest] Skipping duplicate: ${query}`);
      continue;
    }

    const { error: insertError } = await supabase
      .from("discovery_sources")
      .insert({
        source_type: "automation",
        source_value: query,
        area: suggestion.area || null,
        status: "active",
        priority_score: 0.5,
        next_scrape_at: new Date().toISOString(),
      });

    if (insertError) {
      // The database normalized-query index closes concurrent read/insert
      // races. A duplicate created by another invocation is a safe skip.
      if (insertError.code === "23505") {
        knownQueryKeys.add(queryKey);
        console.log(`[auto-suggest] Concurrent duplicate skipped: ${query}`);
        continue;
      }
      console.error(
        `[auto-suggest] Insert failed for "${query}":`,
        insertError.message,
      );
      continue;
    }

    added++;
    knownQueryKeys.add(queryKey);
    results.push(suggestion);
    console.log(`[auto-suggest] Added: "${query}" (${suggestion.area})`);
  }

  console.log(`[auto-suggest] Added ${added} new sources`);
  return { suggestions_added: added, suggestions: results };
}

// ---------------------------------------------------------------------------
// LLM call
// ---------------------------------------------------------------------------

async function callLLM(userContent: string): Promise<Suggestion[]> {
  const apiKey = Deno.env.get("MIMO_API_KEY") ?? Deno.env.get("LLM_API_KEY") ??
    Deno.env.get("OPENAI_API_KEY");
  const baseUrl =
    (Deno.env.get("MIMO_BASE_URL") ?? Deno.env.get("LLM_BASE_URL") ??
      "https://api.openai.com/v1")
      .replace(/\/+$/, "");
  const model = Deno.env.get("MIMO_MODEL") ?? Deno.env.get("LLM_MODEL") ??
    Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

  if (!apiKey) {
    console.log("[auto-suggest] No LLM API key configured, skipping");
    return [];
  }

  try {
    const resp = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.7,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SUGGESTION_SYSTEM_PROMPT },
          { role: "user", content: userContent },
        ],
      }),
    }, 25_000);

    if (!resp.ok) {
      console.error(`[auto-suggest] LLM API error: ${resp.status}`);
      return [];
    }

    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) return [];

    const parsed = JSON.parse(content) as { suggestions?: Suggestion[] };
    if (!Array.isArray(parsed.suggestions)) return [];

    return parsed.suggestions.filter(
      (s) => s.query && typeof s.query === "string",
    );
  } catch (e) {
    console.error("[auto-suggest] LLM call failed:", e);
    return [];
  }
}
