// ============================================================================
// scrape_locations.mjs
// ----------------------------------------------------------------------------
// Scrapes Instagram location pages for posts tagged at each restaurant.
// Uses instagram-search-scraper (searchType=place) — the same actor that
// the existing place discovery uses. Returns posts with engagement data.
//
// Flow:
//   1. Query DB for restaurants with Instagram location URLs
//   2. Filter out recently scraped ones (dedup)
//   3. For each restaurant, search by name to find its location page + posts
//   4. Flatten and map posts to the hashtag scraper format (so existing
//      ingest-location-posts edge function can process them)
//   5. Save results to datasets/ folder
//
// Usage:
//   node scripts/scrape_locations.mjs                # scrape all due restaurants
//   node scripts/scrape_locations.mjs --limit 20     # scrape max 20 restaurants
//   node scripts/scrape_locations.mjs --area "kelana jaya"  # filter by area
// ============================================================================

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { runAndFetch } from "./apify.mjs";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(scriptDir, "..");
const datasetsDir = join(projectRoot, "datasets");

// Load .env
try {
  const envContent = await readFile(join(projectRoot, ".env"), "utf8");
  for (const line of envContent.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (key && !process.env[key]) process.env[key] = value;
  }
} catch {}

const projectRef = process.env.SUPABASE_PROJECT_REF ?? "npmdrgpypkozdjtiplmf";
const anonKey = process.env.SUPABASE_ANON_KEY ??
  "sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH";
const supabaseUrl = process.env.SUPABASE_URL ??
  `https://${projectRef}.supabase.co`;

const SEARCH_ACTOR = "apify/instagram-search-scraper";
const SCRAPE_COOLDOWN_HOURS = 7;

// Parse args
const args = process.argv.slice(2);
const limitFlag = args.indexOf("--limit");
const scrapeLimit = limitFlag !== -1 ? Number(args[limitFlag + 1]) ?? 50 : 50;
const areaFlag = args.indexOf("--area");
const areaFilter = areaFlag !== -1 ? args[areaFlag + 1] : null;

// ---------------------------------------------------------------------------
// Query restaurants that need scraping
// ---------------------------------------------------------------------------
async function getDueRestaurants() {
  const since = new Date(Date.now() - SCRAPE_COOLDOWN_HOURS * 3600_000).toISOString();

  // Step 1: Get place sources with Instagram location URLs
  const srcResp = await fetch(
    `${supabaseUrl}/rest/v1/restaurant_sources?` +
    `select=restaurant_id,url` +
    `&platform=eq.instagram` +
    `&source_type=eq.place` +
    `&url=not.is.null` +
    `&limit=200`,
    {
      headers: {
        "Authorization": `Bearer ${anonKey}`,
        "apikey": anonKey,
      },
    }
  );

  if (!srcResp.ok) {
    const text = await srcResp.text();
    throw new Error(`Failed to query restaurant_sources: ${srcResp.status} ${text}`);
  }

  const sources = await srcResp.json();

  // Dedupe by restaurant_id, keep first location URL per restaurant
  const restMap = new Map();
  for (const src of sources) {
    if (!restMap.has(src.restaurant_id)) {
      restMap.set(src.restaurant_id, src.url);
    }
  }

  if (restMap.size === 0) return [];

  // Step 2: Get restaurant details and filter by last_scraped_at
  const restIds = [...restMap.keys()];
  const restResp = await fetch(
    `${supabaseUrl}/rest/v1/restaurants?` +
    `select=id,name,last_scraped_at` +
    `&id=in.(${restIds.join(",")})` +
    `&or=(last_scraped_at.is.null,last_scraped_at.lt.${since})` +
    `&limit=${scrapeLimit}`,
    {
      headers: {
        "Authorization": `Bearer ${anonKey}`,
        "apikey": anonKey,
      },
    }
  );

  if (!restResp.ok) {
    const text = await restResp.text();
    throw new Error(`Failed to query restaurants: ${restResp.status} ${text}`);
  }

  const restaurants = await restResp.json();

  // Attach location_url from the sources map
  return restaurants.map((r) => ({
    id: r.id,
    name: r.name,
    location_url: restMap.get(r.id),
  }));
}

// ---------------------------------------------------------------------------
// Mark restaurants as scraped
// ---------------------------------------------------------------------------
async function markScraped(restaurantIds) {
  if (restaurantIds.length === 0) return;
  const now = new Date().toISOString();

  const resp = await fetch(
    `${supabaseUrl}/rest/v1/restaurants?id=in.(${restaurantIds.join(",")})`,
    {
      method: "PATCH",
      headers: {
        "Authorization": `Bearer ${anonKey}`,
        "apikey": anonKey,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({ last_scraped_at: now }),
    }
  );

  if (!resp.ok) {
    const text = await resp.text();
    console.warn(`  Warning: failed to mark scraped: ${resp.status} ${text}`);
  }
}

// ---------------------------------------------------------------------------
// Map search scraper post to hashtag scraper format (for toStagingRow)
// ---------------------------------------------------------------------------
function mapSearchPostToHashtagFormat(post, placeName) {
  // Build a hashtag-scraper-compatible URL
  const url = post.code
    ? `https://www.instagram.com/p/${post.code}/`
    : null;
  if (!url) return null;

  // Caption: search scraper returns { text } object
  let caption = null;
  if (post.caption && typeof post.caption === "object" && "text" in post.caption) {
    caption = post.caption.text;
  } else if (typeof post.caption === "string") {
    caption = post.caption;
  }

  // Cover image: search scraper uses image_versions2.candidates
  let displayUrl = null;
  if (post.image_versions2 && typeof post.image_versions2 === "object") {
    const candidates = post.image_versions2.candidates;
    if (Array.isArray(candidates) && candidates.length > 0) {
      displayUrl = candidates[0].url;
    }
  }

  // Timestamp: search scraper uses taken_at (unix seconds)
  let timestamp = null;
  if (typeof post.taken_at === "number") {
    timestamp = new Date(post.taken_at * 1000).toISOString();
  }

  // Location: search scraper uses location.location_id
  let locationId = null;
  let locationName = placeName || null;
  if (post.location && typeof post.location === "object") {
    if (post.location.location_id) locationId = String(post.location.location_id);
    if (post.location.name) locationName = post.location.name;
  }

  // Author: search scraper uses user.username
  let authorName = null;
  let ownerId = null;
  if (post.user && typeof post.user === "object") {
    authorName = post.user.username ?? null;
    if (post.user.pk) ownerId = String(post.user.pk);
  }

  // Hashtags: extract from caption text
  const tags = [];
  if (caption) {
    const matches = caption.match(/#(\w+)/g);
    if (matches) {
      for (const m of matches) {
        tags.push(m.slice(1));
      }
    }
  }

  // Return in hashtag-scraper format (what toStagingRow expects)
  return {
    url,
    ownerUsername: authorName,
    ownerId,
    caption,
    displayUrl,
    likesCount: post.like_count ?? 0,
    commentsCount: post.comment_count ?? 0,
    timestamp,
    locationId,
    locationName,
    hashtags: tags,
    type: post.media_type === 1 ? "Image" : post.media_type === 2 ? "Video" : "Sidecar",
    productType: post.product_type || "feed",
  };
}

// ---------------------------------------------------------------------------
// Scrape via instagram-search-scraper (searchType=place)
// ---------------------------------------------------------------------------
async function scrapePlaces(queries) {
  const apifyToken = process.env.APIFY_TOKEN;
  if (!apifyToken) {
    throw new Error("APIFY_TOKEN env variable is required");
  }

  console.log(`  Calling Apify: ${SEARCH_ACTOR}`);
  console.log(`  Searching ${queries.length} queries...`);

  const input = {
    search: queries.join(","),
    searchType: "place",
    searchLimit: queries.length * 3, // 3 results per query
    addParentData: false,
  };

  const items = await runAndFetch(SEARCH_ACTOR, input, {
    token: apifyToken,
    timeoutSecs: 300,
  });

  if (!items || items.length === 0) {
    console.log("  No places found.");
    return [];
  }

  console.log(`  Found ${items.length} place results`);
  return items;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log("MakanSpot — Location Page Scraper\n");

  // Step 1: Get restaurants that need scraping
  console.log("[1] Querying restaurants due for scraping...");
  const restaurants = await getDueRestaurants();

  if (restaurants.length === 0) {
    console.log("  All restaurants were scraped recently. Nothing to do.");
    console.log(`  (Cooldown: ${SCRAPE_COOLDOWN_HOURS}h between scrapes per restaurant)`);
    return;
  }

  console.log(`  Found ${restaurants.length} restaurants to scrape:`);
  for (const r of restaurants) {
    console.log(`    - ${r.name}`);
  }

  // Step 2: Build search queries from restaurant names
  // Sanitize names: remove special chars that Apify rejects
  const queries = restaurants.map((r) =>
    r.name.replace(/[^a-zA-Z0-9\s]/g, "").trim()
  );

  // Step 3: Search for places via Apify
  console.log(`\n[2] Searching for place pages...`);
  const places = await scrapePlaces(queries);

  if (places.length === 0) {
    console.log("\n  No place results found.");
    await markScraped(restaurants.map((r) => r.id));
    return;
  }

  // Step 4: Flatten posts from all places into hashtag-scraper format
  const allPosts = [];
  const matchedRestaurants = new Set();

  for (const place of places) {
    const placeName = place.name || "Unknown";
    const posts = place.posts || [];
    // location_id is at the place level, not the post level
    const placeLocationId = place.location_id ? String(place.location_id) : null;

    if (posts.length === 0) continue;

    console.log(`  ${placeName} (loc: ${placeLocationId}): ${posts.length} posts`);

    for (const post of posts) {
      const mapped = mapSearchPostToHashtagFormat(post, placeName);
      if (mapped) {
        // Inject the place's location_id into each post
        if (placeLocationId && !mapped.locationId) {
          mapped.locationId = placeLocationId;
        }
        allPosts.push(mapped);
        matchedRestaurants.add(placeName);
      }
    }
  }

  if (allPosts.length === 0) {
    console.log("\n  No posts found from any location.");
    await markScraped(restaurants.map((r) => r.id));
    return;
  }

  // Step 5: Save to datasets
  await mkdir(datasetsDir, { recursive: true });
  const dateStr = new Date().toISOString().slice(0, 10);
  const outPath = join(datasetsDir, `locations-${dateStr}.json`);
  await writeFile(outPath, JSON.stringify(allPosts, null, 2), "utf8");
  console.log(`\n[3] Saved ${allPosts.length} posts to: ${outPath}`);

  // Step 6: Mark as scraped
  await markScraped(restaurants.map((r) => r.id));
  console.log(`  Marked ${restaurants.length} restaurants as scraped.`);

  // Step 7: Summary
  const withLikes = allPosts.filter((p) => (p.likesCount ?? 0) > 0).length;
  const withComments = allPosts.filter((p) => (p.commentsCount ?? 0) > 0).length;
  console.log(`\n[Done]`);
  console.log(`  Total posts: ${allPosts.length}`);
  console.log(`  With likes: ${withLikes}`);
  console.log(`  With comments: ${withComments}`);
  console.log(`\n  Next: ingest these posts into restaurants.`);
  console.log(`  node scripts/run_pipeline.mjs "${outPath}"`);
}

main().catch((err) => {
  console.error("ERROR:", err.message ?? err);
  process.exit(1);
});
