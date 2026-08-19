// ============================================================================
// discover_hashtags.mjs
// ----------------------------------------------------------------------------
// Discovers trending food hashtags on Instagram.
// Two strategies:
//   1. LLM-suggested: Ask AI to suggest trending Malaysian food hashtags
//   2. Apify search: Use instagram-search-scraper to find related hashtags
//
// Usage (from the project root):
//   node scripts/discover_hashtags.mjs                    # default: LLM + search
//   node scripts/discover_hashtags.mjs --llm-only         # LLM suggestions only
//   node scripts/discover_hashtags.mjs --search-only      # Apify search only
//   node scripts/discover_hashtags.mjs --top 10           # return top 10
//
// Config via env:
//   APIFY_TOKEN  — required for search mode
//   OPENAI_API_KEY or LLM_API_KEY — required for LLM mode
// =============================================================================

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { runAndFetch } from "./apify.mjs";

// ---------------------------------------------------------------------------
// Load .env
// ---------------------------------------------------------------------------
const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(scriptDir, "..");
const envPath = join(projectRoot, ".env");
try {
  const envContent = await readFile(envPath, "utf8");
  for (const line of envContent.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (key && !process.env[key]) process.env[key] = value;
  }
} catch { /* no .env — fine */ }

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const datasetsDir = join(projectRoot, "datasets");

const SEARCH_ACTOR = "apify/instagram-search-scraper";

// Base hashtags that are always included (proven Malaysian food tags)
const BASE_HASHTAGS = [
  "malaysiafood",
  "klfoodie",
  "penangfood",
  "makanla",
  "nasilemak",
  "streetfoodkl",
  "hiddengemkl",
  "jalanjalanbest",
  "kopitiam",
  "malaysianfood",
];

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
const llmOnly = args.includes("--llm-only");
const searchOnly = args.includes("--search-only");

const topFlag = args.indexOf("--top");
const topN = topFlag !== -1 && args[topFlag + 1]
  ? Math.max(1, Number(args[topFlag + 1]))
  : 15;

// ---------------------------------------------------------------------------
// Strategy 1: LLM-suggested hashtags
// ---------------------------------------------------------------------------

/**
 * Ask the LLM to suggest trending Malaysian food hashtags.
 * Returns an array of hashtag strings.
 */
async function suggestHashtagsWithLLM() {
  // Support multiple providers: MiMo (Xiaomi), OpenAI, DeepSeek, etc.
  // Priority: MIMO_* > LLM_* > OPENAI_*
  const apiKey = process.env.MIMO_API_KEY ?? process.env.LLM_API_KEY ?? process.env.OPENAI_API_KEY;
  const baseUrl = (process.env.MIMO_BASE_URL ?? process.env.LLM_BASE_URL ?? "https://api.openai.com/v1")
    .replace(/\/+$/, "");
  const model = process.env.MIMO_MODEL ?? process.env.LLM_MODEL ?? process.env.OPENAI_MODEL ?? "gpt-4o-mini";

  if (!apiKey) {
    console.log("  LLM not configured (no MIMO_API_KEY/LLM_API_KEY/OPENAI_API_KEY) — skipping");
    return [];
  }

  console.log(`  Using LLM: ${model} @ ${baseUrl}`);

  const systemPrompt = `You are a Malaysian food trend analyst. Given the current date, suggest Instagram hashtags that food bloggers in Malaysia are likely using RIGHT NOW for trending restaurants, new openings, viral food, and hidden gems.

Rules:
- Return ONLY a JSON array of hashtag strings (lowercase, no # prefix)
- Include a mix of: popular established tags, trending new tags, location-specific tags
- Focus on: Kuala Lumpur, Penang, Johor Bahru, Malacca, East Malaysia
- Include both English and Malay hashtags
- Return exactly 15 hashtags
- No explanations, just the JSON array`;

  const userPrompt = `Suggest 15 trending Instagram food hashtags for Malaysian food bloggers to use RIGHT NOW. Think about what's popular in the Malaysian food scene: new restaurant openings, viral food trends, seasonal dishes, and hidden gems.

Current date: ${new Date().toISOString().slice(0, 10)}`;

  try {
    const resp = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.7,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    });

    if (!resp.ok) {
      const errText = await resp.text().catch(() => "");
      console.warn(`  LLM call failed: ${resp.status} ${errText.slice(0, 200)}`);
      return [];
    }

    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) {
      console.warn("  LLM returned empty content");
      return [];
    }

    // Parse JSON from response — handle both raw arrays and { hashtags: [...] }
    // Also handle markdown code fences (```json ... ```)
    let cleaned = content.trim();
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.replace(/^```(?:json)?\s*\n?/, "").replace(/\n?```\s*$/, "");
    }

    const parsed = JSON.parse(cleaned);
    const tags = Array.isArray(parsed) ? parsed : parsed.hashtags ?? [];
    const result = tags
      .map((t) => String(t).replace(/^#/, "").trim().toLowerCase())
      .filter((t) => t.length >= 3 && t.length <= 30);

    console.log(`  Got ${result.length} hashtags from LLM`);
    return result;
  } catch (err) {
    console.warn(`  LLM suggestion failed: ${err.message}`);
    return [];
  }
}

// ---------------------------------------------------------------------------
// Strategy 2: Apify search-based discovery
// ---------------------------------------------------------------------------

/**
 * Search Instagram for hashtags related to a keyword.
 */
async function searchHashtags(term, token) {
  const input = {
    search: term,
    searchType: "hashtag",
    searchLimit: 10,
  };

  try {
    const items = await runAndFetch(SEARCH_ACTOR, input, { token });
    if (!items || items.length === 0) return [];

    return items.map((item) => {
      let name = item.name ?? item.hashtag ?? "";
      try { name = decodeURIComponent(name); } catch { /* keep as-is */ }
      name = name.replace(/^#/, "").trim().toLowerCase();

      let postCount = Number(item.postsCount ?? 0);
      if (postCount === 0 && item.posts) {
        const match = String(item.posts).match(/([\d.]+)\s*([KkMm]?)/);
        if (match) {
          postCount = parseFloat(match[1]);
          if (match[2].toUpperCase() === "K") postCount *= 1000;
          if (match[2].toUpperCase() === "M") postCount *= 1000000;
          postCount = Math.round(postCount);
        }
      }

      return { hashtag: name, postCount, source: term };
    });
  } catch (err) {
    console.warn(`      Warning: search for "${term}" failed: ${err.message}`);
    return [];
  }
}

/**
 * Discover trending hashtags via Apify search.
 * Searches for each base hashtag and collects related tags.
 */
async function discoverViaSearch(token) {
  const searchTerms = BASE_HASHTAGS.slice(0, 5); // limit to 5 searches to save costs
  console.log(`  Searching Apify for ${searchTerms.length} terms...`);

  const allHashtags = [];
  for (const term of searchTerms) {
    process.stdout.write(`    "${term}"...`);
    const results = await searchHashtags(term, token);
    console.log(` ${results.length} results`);
    allHashtags.push(...results);
  }

  // Deduplicate and rank
  const seen = new Map();
  for (const h of allHashtags) {
    if (!h.hashtag || h.hashtag.length < 3) continue;
    const existing = seen.get(h.hashtag);
    if (!existing || h.postCount > existing.postCount) {
      seen.set(h.hashtag, h);
    }
  }

  return [...seen.values()]
    .sort((a, b) => b.postCount - a.postCount)
    .map((h) => h.hashtag);
}

// ---------------------------------------------------------------------------
// Main discovery function
// ---------------------------------------------------------------------------

/**
 * Discover trending hashtags using available strategies.
 * Priority: LLM suggestions first (most creative/timely), then base, then search.
 */
async function discoverTrending(token) {
  console.log("\nDiscovering trending hashtags...");

  // Use arrays to preserve priority order (not Set which loses order)
  const result = [];
  const seen = new Set();

  function addTags(tags, source) {
    for (const t of tags) {
      const tag = t.toLowerCase().trim();
      if (tag.length < 3 || tag.length > 30 || seen.has(tag)) continue;
      seen.add(tag);
      result.push(tag);
    }
  }

  // Strategy 1: LLM suggestions (highest priority — most creative/timely)
  if (!searchOnly) {
    console.log("\n  [1] LLM hashtag suggestions...");
    const llmTags = await suggestHashtagsWithLLM();
    if (llmTags.length > 0) {
      console.log(`  Got ${llmTags.length} LLM suggestions: ${llmTags.slice(0, 5).join(", ")}...`);
      addTags(llmTags, "llm");
    }
  }

  // Strategy 2: Base hashtags (proven performers)
  console.log("\n  [2] Base hashtags...");
  addTags(BASE_HASHTAGS, "base");
  console.log(`  ${BASE_HASHTAGS.length} base hashtags added`);

  // Strategy 3: Apify search (supplementary)
  if (!llmOnly && token) {
    console.log("\n  [3] Apify hashtag search...");
    const searchTags = await discoverViaSearch(token);
    if (searchTags.length > 0) {
      console.log(`  Found ${searchTags.length} hashtags from search`);
      addTags(searchTags, "search");
    }
  }

  // Limit to topN
  const final = result.slice(0, topN);

  console.log(`\n  Final: ${final.length} hashtags selected`);
  return final;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const token = process.env.APIFY_TOKEN;

  const trending = await discoverTrending(token);

  if (trending.length === 0) {
    console.log("No trending hashtags found.");
    return [];
  }

  // Print results
  console.log("\n  Trending hashtags:");
  console.log("  ─────────────────────────────────────────────────");
  for (let i = 0; i < trending.length; i++) {
    console.log(`  ${String(i + 1).padStart(2)}. #${trending[i]}`);
  }

  // Save for audit and pipeline consumption
  await mkdir(datasetsDir, { recursive: true });
  const dateStr = new Date().toISOString().slice(0, 10);
  const tagsPath = join(datasetsDir, `trending-tags-${dateStr}.json`);
  await writeFile(tagsPath, JSON.stringify(trending, null, 2), "utf8");
  console.log(`\n  Saved to: ${tagsPath}`);

  return trending;
}

// Run if called directly (not imported)
const isMain = process.argv[1] &&
  (process.argv[1].endsWith("discover_hashtags.mjs") ||
   process.argv[1].endsWith("discover_hashtags.js"));

if (isMain) {
  main().catch((err) => {
    console.error("ERROR:", err.message ?? err);
    process.exit(1);
  });
}

export { discoverTrending, searchHashtags };
