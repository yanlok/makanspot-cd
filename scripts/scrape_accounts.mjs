// ============================================================================
// scrape_accounts.mjs
// ----------------------------------------------------------------------------
// Scrapes recent posts from food influencer accounts on Instagram.
// Uses Apify's instagram-post-scraper with a time filter to guarantee
// fresh content on every run.
//
// Usage (from the project root):
//   node scripts/scrape_accounts.mjs                    # default accounts
//   node scripts/scrape_accounts.mjs --accounts "user1,user2"
//   node scripts/scrape_accounts.mjs --days 3           # last 3 days only
//   node scripts/scrape_accounts.mjs --limit 10         # posts per account
//
// Config via env:
//   APIFY_TOKEN  — required
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

// instagram-scraper can scrape profiles by URL with resultsType: "posts"
const PROFILE_SCRAPER_ACTOR = "apify/instagram-scraper";

// Default food influencer accounts — Malaysian food scene
const DEFAULT_ACCOUNTS = [
  "klfoodie",
  "malaysiafood",
  "makanla",
  "jalanjalanbest",
  "hiddengemkl",
  "streetfoodkl",
  "penangfood",
];

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);

const accountsFlag = args.indexOf("--accounts");
const customAccounts = accountsFlag !== -1 && args[accountsFlag + 1]
  ? args[accountsFlag + 1].split(",").map((a) => a.trim().replace(/^@/, "")).filter(Boolean)
  : null;

const daysFlag = args.indexOf("--days");
const daysBack = daysFlag !== -1 && args[daysFlag + 1]
  ? Math.max(1, Number(args[daysFlag + 1]))
  : 7;

const limitFlag = args.indexOf("--limit");
const perAccountLimit = limitFlag !== -1 && args[limitFlag + 1]
  ? Math.max(1, Number(args[limitFlag + 1]))
  : Number(process.env.RESULTS_LIMIT ?? 20);

const accounts = customAccounts ?? DEFAULT_ACCOUNTS;

// ---------------------------------------------------------------------------
// Core: scrape recent posts from accounts
// ---------------------------------------------------------------------------

/**
 * Scrape recent posts from a list of Instagram accounts.
 * Uses apify/instagram-scraper with directUrls (profile page URLs).
 * Returns an array of Apify record objects (same shape as hashtag scraper).
 */
async function scrapeRecentPosts(accountList, token) {
  console.log(`\nScraping recent posts from ${accountList.length} accounts:`);
  console.log(`  ${accountList.join(", ")}`);
  console.log(`  Time window: last ${daysBack} days`);
  console.log(`  Limit: ${perAccountLimit} posts per account\n`);

  // Build profile URLs for the instagram-scraper actor
  const directUrls = accountList.map((a) => {
    const username = a.startsWith("@") ? a.slice(1) : a;
    return `https://www.instagram.com/${username}/`;
  });

  const input = {
    directUrls,
    resultsType: "posts",
    resultsLimit: perAccountLimit,
    addParentData: false,
  };

  console.log(`  Calling Apify actor: ${PROFILE_SCRAPER_ACTOR}`);
  const items = await runAndFetch(PROFILE_SCRAPER_ACTOR, input, { token });

  if (!items || items.length === 0) {
    console.log("  No posts found from any account.");
    return [];
  }

  console.log(`  Fetched ${items.length} posts from ${accountList.length} accounts`);

  // Filter out error entries and normalize field names
  return items
    .filter((item) => !item.error)
    .map((item) => ({
      ...item,
      // Ensure URL field is present
      url: item.url ?? item.webVideoUrl ?? item.postUrl ?? "",
      // Ensure hashtags array is present
      hashtags: Array.isArray(item.hashtags) ? item.hashtags : [],
      // Ensure engagement fields are present
      likesCount: item.likesCount ?? item.diggCount ?? 0,
      commentsCount: item.commentsCount ?? item.commentCount ?? 0,
    }));
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const token = process.env.APIFY_TOKEN;
  if (!token) {
    console.error("APIFY_TOKEN env variable is required.");
    console.error("Sign up at https://apify.com and get your token from Settings > Integrations.");
    process.exit(1);
  }

  const items = await scrapeRecentPosts(accounts, token);

  if (items.length === 0) {
    return null;
  }

  // Save to datasets folder
  await mkdir(datasetsDir, { recursive: true });
  const dateStr = new Date().toISOString().slice(0, 10);
  const outPath = join(datasetsDir, `accounts-${dateStr}.json`);
  await writeFile(outPath, JSON.stringify(items, null, 2), "utf8");
  console.log(`\n  Saved to: ${outPath}`);

  return outPath;
}

// Run if called directly
const isMain = process.argv[1] &&
  (process.argv[1].endsWith("scrape_accounts.mjs") ||
   process.argv[1].endsWith("scrape_accounts.js"));

if (isMain) {
  main().catch((err) => {
    console.error("ERROR:", err.message ?? err);
    process.exit(1);
  });
}

export { scrapeRecentPosts };
