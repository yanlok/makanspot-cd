/// <reference path="./deno.d.ts" />
import { type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { validateImage } from "./image-validation.ts";
import { fetchWithTimeout } from "./http.ts";

// Enrichment helpers — core logic with cleaner, more explicit naming.

export interface VenueExtraction {
  is_restaurant: boolean;
  name: string | null;
  address: string | null;
  city: string | null;
  cuisine: string | null;
  price_range: "$" | "$$" | "$$$" | "$$$$" | null;
  description: string | null;
  categories: string[];
  confidence: number;
  phone: string | null;
  website: string | null;
  operating_hours: string | null;
}

export interface GeoResult {
  latitude: number;
  longitude: number;
  formatted_address: string;
}

export interface ReverseGeoResult {
  address: string | null;
  city: string | null;
}

export const CATEGORY_TAXONOMY = [
  "Malay",
  "Chinese",
  "Indian",
  "Mamak",
  "Cafe",
  "Western",
  "Japanese",
  "Korean",
  "Thai",
  "Middle Eastern",
  "Seafood",
  "Dessert & Bakery",
  "Fast Food",
  "Street Food",
  "Vegetarian",
] as const;

const EXTRACTION_SYSTEM_PROMPT =
  `You extract restaurant/cafe/eatery details from Malaysian Instagram food captions.
Return STRICT JSON only, matching this TypeScript type:
{
  "is_restaurant": boolean,   // false if the caption is not about one specific eatery
  "name": string | null,      // the venue name only, no emojis/hashtags
  "address": string | null,   // full street address if present in the caption
  "city": string | null,      // e.g. "Kuala Lumpur", "Petaling Jaya"
  "cuisine": string | null,   // e.g. "Middle Eastern", "Chinese", "Cafe"
  "price_range": "$" | "$$" | "$$$" | "$$$$" | null,
  "description": string | null, // one clean sentence describing the food/spot
  "categories": string[],     // 1-3 items from: ["Malay","Chinese","Indian","Mamak","Cafe","Western","Japanese","Korean","Thai","Middle Eastern","Seafood","Dessert & Bakery","Fast Food","Street Food","Vegetarian"]
  "confidence": number,       // 0..1, your confidence that name+location are correct
  "phone": string | null,     // phone number if mentioned
  "website": string | null,   // website URL if mentioned
  "operating_hours": string | null // hours if mentioned
}
Rules: never invent facts. Only use categories from the list; if none fit, return []. Output JSON with no markdown fences.`;

/** Ask the LLM to extract a structured venue from a caption. */
export async function extractVenue(
  caption: string,
  hashtags: string[],
  author: string | null,
): Promise<VenueExtraction> {
  const apiKey = Deno.env.get("MIMO_API_KEY") ?? Deno.env.get("LLM_API_KEY") ??
    Deno.env.get("OPENAI_API_KEY");
  const baseUrl =
    (Deno.env.get("MIMO_BASE_URL") ?? Deno.env.get("LLM_BASE_URL") ??
      "https://api.openai.com/v1")
      .replace(/\/+$/, "");
  const model = Deno.env.get("MIMO_MODEL") ?? Deno.env.get("LLM_MODEL") ??
    Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

  const fallback: VenueExtraction = {
    is_restaurant: false,
    name: null,
    address: null,
    city: null,
    cuisine: null,
    price_range: null,
    description: null,
    categories: [],
    confidence: 0,
    phone: null,
    website: null,
    operating_hours: null,
  };

  if (!apiKey) return fallback;

  const userContent = `Author: @${author ?? "unknown"}\nHashtags: ${
    hashtags.join(", ")
  }\n\nCaption:\n${caption}`;

  try {
    const resp = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: EXTRACTION_SYSTEM_PROMPT },
          { role: "user", content: userContent },
        ],
      }),
    }, 25_000);

    if (!resp.ok) return fallback;
    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) return fallback;

    const parsed = JSON.parse(content) as Partial<VenueExtraction>;
    return {
      is_restaurant: parsed.is_restaurant === true,
      name: parsed.name ?? null,
      address: parsed.address ?? null,
      city: parsed.city ?? null,
      cuisine: parsed.cuisine ?? null,
      price_range: parsed.price_range ?? null,
      description: parsed.description ?? null,
      categories: normalizeCategories(parsed.categories),
      confidence: typeof parsed.confidence === "number"
        ? Math.max(0, Math.min(1, parsed.confidence))
        : 0,
      phone: parsed.phone ?? null,
      website: parsed.website ?? null,
      operating_hours: parsed.operating_hours ?? null,
    };
  } catch (_e) {
    return fallback;
  }
}

/** Resolve a venue name/address into coordinates via Mapbox Geocoding. */
export async function geocode(
  name: string | null,
  address: string | null,
  city: string | null,
): Promise<GeoResult | null> {
  const token = Deno.env.get("MAPBOX_TOKEN");
  if (!token) return null;

  const query = [name, address, city, "Malaysia"]
    .filter((p) => p && p.trim().length > 0)
    .join(", ");
  if (!query) return null;

  try {
    const url = new URL(
      `https://api.mapbox.com/geocoding/v5/mapbox.places/${
        encodeURIComponent(query)
      }.json`,
    );
    url.searchParams.set("access_token", token);
    url.searchParams.set("country", "my");
    url.searchParams.set("limit", "1");
    url.searchParams.set("permanent", "true");

    const resp = await fetchWithTimeout(url.toString(), {}, 10_000);
    if (!resp.ok) return null;
    const data = await resp.json();
    const feature = data?.features?.[0];
    if (!feature) return null;

    const coords = feature?.geometry?.coordinates;
    if (!Array.isArray(coords) || coords.length < 2) return null;

    return {
      latitude: coords[1],
      longitude: coords[0],
      formatted_address: feature.place_name ?? address ?? query,
    };
  } catch {
    return null;
  }
}

export function parseReverseGeocode(
  payload: unknown,
): ReverseGeoResult | null {
  const data = payload as Record<string, any>;
  const feature = data?.features?.[0];
  if (!feature) return null;
  const properties = feature.properties ?? {};
  const context = properties.context ?? feature.context ?? {};
  const contextItems = Array.isArray(context)
    ? context
    : Object.values(context);
  const cityItem = context?.place ?? context?.locality ??
    contextItems.find((item: any) =>
      item?.id?.startsWith?.("place.") || item?.id?.startsWith?.("locality.") ||
      item?.mapbox_id?.includes?.("place") ||
      item?.mapbox_id?.includes?.("locality")
    );
  const address = properties.full_address ?? properties.place_formatted ??
    feature.place_name ?? properties.name ?? null;
  const city = cityItem?.name ?? cityItem?.text ??
    properties.context?.place?.name ??
    properties.context?.locality?.name ?? null;
  return { address, city };
}

/** Reverse geocode a lat/lng into address + city (free-tier safe). */
export async function reverseGeocode(
  latitude: number,
  longitude: number,
  fetcher: typeof fetch = fetch,
): Promise<ReverseGeoResult | null> {
  const token = Deno.env.get("MAPBOX_TOKEN");
  if (!token) return null;
  const url = new URL("https://api.mapbox.com/search/geocode/v6/reverse");
  url.searchParams.set("latitude", String(latitude));
  url.searchParams.set("longitude", String(longitude));
  url.searchParams.set("country", "my");
  url.searchParams.set("permanent", "true");
  url.searchParams.set("access_token", token);
  try {
    const response = fetcher === fetch
      ? await fetchWithTimeout(url.toString(), {}, 10_000)
      : await fetcher(url.toString());
    if (!response.ok) return null;
    return parseReverseGeocode(await response.json());
  } catch {
    return null;
  }
}

/**
 * Pre-filter: returns true if the caption/hashtags strongly suggest this
 * is NOT about a specific restaurant. Saves LLM costs.
 */
export function isLikelyNotRestaurant(
  caption: string,
  hashtags: string[],
): boolean {
  const text = caption.toLowerCase();
  const tags = hashtags.map((h) => h.toLowerCase());

  const recipeSignals = [
    "cara buat",
    "cara masak",
    "resepi",
    "recipe",
    "how to make",
    "bahan-bahan",
    "ingredients",
    "step by step",
    "tutorial",
  ];
  if (recipeSignals.some((s) => text.includes(s))) return true;

  const genericSignals = [
    "top 10",
    "top 5",
    "best food in",
    "food guide",
    "makan apa",
    "what to eat",
    "food court",
    "buffet",
    "all you can eat",
  ];
  if (genericSignals.some((s) => text.includes(s))) return true;

  const adSignals = [
    "ad",
    "sponsored",
    "partner",
    "paid",
    "collab",
    "promotion",
  ];
  if (tags.some((t) => adSignals.includes(t))) return true;
  if (/#(ad|sponsored|partner|paid|collab|promotion)\b/i.test(caption)) {
    return true;
  }

  if (caption.trim().length < 20 && !text.includes("@")) return true;

  return false;
}

/** Popularity score in 0..100 from engagement metrics. */
export function popularityScore(
  likes: number,
  comments: number,
  views: number,
): number {
  const l = Math.max(0, likes);
  const c = Math.max(0, comments);
  const v = Math.max(0, views);

  // Likes: log10(likes+1) / 4 * 60, maxes at 10K likes
  const likeScore = Math.min(60, Math.round((Math.log10(l + 1) / 4) * 60));
  // Comments: log10(comments+1) / 3 * 25, maxes at 1K comments
  const commentScore = Math.min(25, Math.round((Math.log10(c + 1) / 3) * 25));
  // Views: log10(views+1) / 6 * 15, maxes at 1M views
  const viewScore = Math.min(15, Math.round((Math.log10(v + 1) / 6) * 15));

  return Math.min(100, likeScore + commentScore + viewScore);
}

/** Normalize a name: lowercase, strip punctuation/accents, collapse whitespace. */
export function normalizeName(name: string | null): string {
  return (name ?? "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

/** Name relationship between two normalized names. */
export function nameRelation(
  a: string,
  b: string,
): "equal" | "prefix" | "none" {
  if (!a || !b) return "none";
  if (a === b) return "equal";
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  if (short.length >= 5 && long.startsWith(short)) return "prefix";
  return "none";
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

const TAXONOMY_LOWER = new Map(
  CATEGORY_TAXONOMY.map((c) => [c.toLowerCase(), c]),
);

/** Keep only valid taxonomy names, de-duplicated. */
export function normalizeCategories(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  const out: string[] = [];
  for (const item of input) {
    const canonical = TAXONOMY_LOWER.get(String(item).trim().toLowerCase());
    if (canonical && !out.includes(canonical)) out.push(canonical);
  }
  return out;
}

const CATEGORY_KEYWORDS: Array<[string, string]> = [
  ["nasi lemak", "Malay"],
  ["nasi", "Malay"],
  ["warung", "Malay"],
  ["warong", "Malay"],
  ["gerai", "Malay"],
  ["sarapan", "Malay"],
  ["melayu", "Malay"],
  ["mamak", "Mamak"],
  ["roti canai", "Mamak"],
  ["teh tarik", "Mamak"],
  ["indian", "Indian"],
  ["banana leaf", "Indian"],
  ["curry", "Indian"],
  ["chinese", "Chinese"],
  ["dim sum", "Chinese"],
  ["wanton", "Chinese"],
  ["wan tan", "Chinese"],
  ["noodle", "Chinese"],
  ["mee", "Chinese"],
  ["yong tau", "Chinese"],
  ["pan mee", "Chinese"],
  ["kopitiam", "Chinese"],
  ["cafe", "Cafe"],
  ["caf\u00e9", "Cafe"],
  ["coffee", "Cafe"],
  ["kopi", "Cafe"],
  ["brunch", "Cafe"],
  ["bistro", "Cafe"],
  ["western", "Western"],
  ["burger", "Western"],
  ["steak", "Western"],
  ["chicken chop", "Western"],
  ["pasta", "Western"],
  ["pizza", "Western"],
  ["japanese", "Japanese"],
  ["sushi", "Japanese"],
  ["ramen", "Japanese"],
  ["omakase", "Japanese"],
  ["korean", "Korean"],
  ["kimchi", "Korean"],
  ["kbbq", "Korean"],
  ["thai", "Thai"],
  ["tom yum", "Thai"],
  ["middle eastern", "Middle Eastern"],
  ["arab", "Middle Eastern"],
  ["kebab", "Middle Eastern"],
  ["shawarma", "Middle Eastern"],
  ["seafood", "Seafood"],
  ["fish", "Seafood"],
  ["crab", "Seafood"],
  ["dessert", "Dessert & Bakery"],
  ["cake", "Dessert & Bakery"],
  ["bakery", "Dessert & Bakery"],
  ["pastry", "Dessert & Bakery"],
  ["donut", "Dessert & Bakery"],
  ["dough", "Dessert & Bakery"],
  ["ice cream", "Dessert & Bakery"],
  ["fast food", "Fast Food"],
  ["fried chicken", "Fast Food"],
  ["vegetarian", "Vegetarian"],
  ["vegan", "Vegetarian"],
  ["street food", "Street Food"],
  ["hawker", "Street Food"],
  ["stall", "Street Food"],
];

/** Fallback classifier: scan cuisine + name + hashtags for category keywords. */
export function deriveCategories(
  cuisine: string | null,
  name: string | null,
  hashtags: string[],
): string[] {
  const haystack = [cuisine ?? "", name ?? "", hashtags.join(" ")]
    .join(" ").toLowerCase();

  const out: string[] = [];
  for (const [keyword, category] of CATEGORY_KEYWORDS) {
    if (haystack.includes(keyword) && !out.includes(category)) {
      out.push(category);
    }
  }
  return out.slice(0, 3);
}

// ---------------------------------------------------------------------------
// Trend score
// ---------------------------------------------------------------------------

/**
 * Calculate trend score from social metrics.
 * Components: mention velocity, creator diversity, engagement, recency.
 */
export function trendScore(opts: {
  mentionsLast7d: number;
  mentionsPrev7d: number;
  uniqueCreators: number;
  totalMentions: number;
  avgEngagement: number;
  daysSinceLastMention: number;
}): number {
  // Mention velocity: ratio of recent vs previous period, capped at 3x
  const velocity = opts.mentionsPrev7d > 0
    ? Math.min(3, opts.mentionsLast7d / opts.mentionsPrev7d)
    : (opts.mentionsLast7d > 0 ? 2 : 0);
  const velocityNorm = Math.min(1, velocity / 3);

  // Creator diversity: unique creators / total mentions, capped at 1
  const diversity = opts.totalMentions > 0
    ? Math.min(1, opts.uniqueCreators / opts.totalMentions)
    : 0;

  // Engagement: log-scaled avg engagement, normalized to 0..1
  const engagementNorm = Math.min(1, Math.log10(opts.avgEngagement + 1) / 4);

  // Recency: decays from 1.0 to 0 over 30 days
  const recency = Math.max(0, 1 - opts.daysSinceLastMention / 30);

  return (
    0.35 * velocityNorm +
    0.25 * diversity +
    0.20 * engagementNorm +
    0.20 * recency
  );
}

// ---------------------------------------------------------------------------
// Image utilities
// ---------------------------------------------------------------------------

export interface ImageCandidate {
  cover_url: string | null;
  caption: string | null;
  hashtags: string[];
  likes: number;
  comments: number;
  posted_at: string | null;
}

export interface RankedImage extends ImageCandidate {
  quality_score: number;
}

export function rankImageCandidate(
  candidate: ImageCandidate,
  nowMs = Date.now(),
): number {
  if (!candidate.cover_url || !/^https?:\/\//i.test(candidate.cover_url)) {
    return 0;
  }
  const text = `${candidate.caption ?? ""} ${candidate.hashtags.join(" ")}`
    .toLowerCase();
  const positive = [
    "food",
    "makan",
    "nasi",
    "cafe",
    "restaurant",
    "restoran",
    "dessert",
    "coffee",
    "ramen",
    "sushi",
  ]
    .filter((word) => text.includes(word)).length;
  const negative = [
    "#ad",
    "sponsored",
    "giveaway",
    "hiring",
    "vacancy",
    "announcement",
    "logo",
    "menu only",
  ]
    .filter((word) => text.includes(word)).length;
  const engagement = Math.min(
    1,
    Math.log10(
      Math.max(0, candidate.likes) + 2 * Math.max(0, candidate.comments) + 1,
    ) / 5,
  );
  const posted = candidate.posted_at ? Date.parse(candidate.posted_at) : NaN;
  const recency = Number.isFinite(posted)
    ? Math.max(0, 1 - Math.max(0, nowMs - posted) / (365 * 86_400_000))
    : 0;
  return Math.max(
    0,
    Math.min(
      1,
      0.55 * engagement + 0.2 * recency + 0.1 + 0.08 * Math.min(2, positive) -
        0.25 * negative,
    ),
  );
}

export function selectBestImageCandidate(
  candidates: ImageCandidate[],
  nowMs = Date.now(),
): RankedImage | null {
  return candidates.map((candidate) => ({
    ...candidate,
    quality_score: rankImageCandidate(candidate, nowMs),
  })).filter((candidate) => candidate.quality_score > 0)
    .sort((a, b) =>
      b.quality_score - a.quality_score ||
      (b.likes + b.comments) - (a.likes + a.comments) ||
      (a.cover_url ?? "").localeCompare(b.cover_url ?? "")
    )[0] ?? null;
}

export function sumComponentCosts(
  costs: Array<number | null | undefined>,
): number {
  return costs.reduce<number>(
    (sum, cost) => sum + Math.max(0, Number(cost ?? 0)),
    0,
  );
}

type DbClient = SupabaseClient<any, any, any, any, any>;

/** Set an image as the restaurant's primary image in restaurant_images. */
export async function setPrimaryImage(
  supabase: DbClient,
  restaurantId: number,
  imageUrl: string | null,
  sourceUrl: string | null = null,
  qualityScore = 0,
): Promise<void> {
  if (!imageUrl) return;

  const { data: existing, error: existingError } = await supabase
    .from("restaurant_images")
    .select("id, is_primary, quality_score")
    .eq("restaurant_id", restaurantId)
    .eq("image_url", imageUrl)
    .maybeSingle();
  if (existingError) {
    throw new Error(`Image lookup failed: ${existingError.message}`);
  }

  const { data: primary, error: primaryError } = await supabase
    .from("restaurant_images")
    .select("id, quality_score")
    .eq("restaurant_id", restaurantId)
    .eq("is_primary", true)
    .maybeSingle();
  if (primaryError) {
    throw new Error(`Primary image lookup failed: ${primaryError.message}`);
  }
  const shouldPromote = !primary ||
    qualityScore > Number(primary.quality_score ?? 0);

  if (existing) {
    const { error } = await supabase.from("restaurant_images").update({
      source_url: sourceUrl,
      quality_score: Math.max(
        Number(existing.quality_score ?? 0),
        qualityScore,
      ),
    }).eq("id", existing.id);
    if (error) {
      throw new Error(`Image metadata update failed: ${error.message}`);
    }
  } else {
    const { error } = await supabase.from("restaurant_images").insert({
      restaurant_id: restaurantId,
      source_url: sourceUrl,
      image_url: imageUrl,
      quality_score: qualityScore,
      is_primary: false,
    });
    if (error && error.code !== "23505") {
      throw new Error(`Image insert failed: ${error.message}`);
    }
  }
  if (!shouldPromote || existing?.is_primary) return;

  const { error: demoteError } = await supabase.from("restaurant_images")
    .update({ is_primary: false })
    .eq("restaurant_id", restaurantId);
  if (demoteError) {
    throw new Error(`Primary image demotion failed: ${demoteError.message}`);
  }

  const { error: promoteError } = await supabase.from("restaurant_images")
    .update({
      is_primary: true,
      source_url: sourceUrl,
      quality_score: qualityScore,
    })
    .eq("restaurant_id", restaurantId)
    .eq("image_url", imageUrl);
  if (promoteError) {
    throw new Error(`Primary image promotion failed: ${promoteError.message}`);
  }
}

/** Download image bytes from a URL. */
export async function fetchImage(
  imageUrl: string,
): Promise<{ bytes: Uint8Array; contentType: string } | null> {
  try {
    const resp = await fetchWithTimeout(
      imageUrl,
      { redirect: "follow" },
      12_000,
    );
    if (!resp.ok) return null;
    const ct = resp.headers.get("content-type") ?? "image/jpeg";
    if (!ct.startsWith("image/")) return null;
    const bytes = new Uint8Array(await resp.arrayBuffer());
    if (bytes.length === 0) return null;
    return { bytes, contentType: ct };
  } catch {
    return null;
  }
}

/** Deterministic storage key for an image. */
export function imageStorageKey(
  restaurantId: number,
  imageUrl: string,
): string {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(imageUrl)) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return `v2-covers/${restaurantId}-${hash.toString(16).padStart(8, "0")}.jpg`;
}

/** Download, re-host to Supabase Storage, and set as primary image. */
export async function persistPrimaryImage(
  supabase: DbClient,
  restaurantId: number,
  imageUrl: string | null,
  qualityScore = 0,
): Promise<void> {
  if (!imageUrl) return;

  const { data: previouslyHosted, error: previousError } = await supabase
    .from("restaurant_images")
    .select("image_url")
    .eq("restaurant_id", restaurantId)
    .eq("source_url", imageUrl)
    .limit(1)
    .maybeSingle();
  if (previousError) {
    throw new Error(`Hosted image lookup failed: ${previousError.message}`);
  }
  if (previouslyHosted?.image_url) {
    await setPrimaryImage(
      supabase,
      restaurantId,
      previouslyHosted.image_url,
      imageUrl,
      qualityScore,
    );
    return;
  }

  // Already on our storage — set directly
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const storageHost = new URL(supabaseUrl).host;
    if (new URL(imageUrl).host === storageHost) {
      await setPrimaryImage(
        supabase,
        restaurantId,
        imageUrl,
        imageUrl,
        qualityScore,
      );
      return;
    }
  } catch {
    return;
  }

  const fetched = await fetchImage(imageUrl);
  if (!fetched) return;

  // Validate image with LLM before uploading
  let restaurantName = "";
  try {
    const { data: restaurant } = await supabase
      .from("restaurants")
      .select("name")
      .eq("id", restaurantId)
      .maybeSingle();
    restaurantName = restaurant?.name ?? "";
  } catch {
    // Continue without name — validation still works
  }

  const validation = await validateImage(imageUrl, restaurantName, fetched);
  if (!validation.approved) {
    console.log(
      `[image-validation] Rejected image for restaurant ${restaurantId}: ${validation.reason} — ${validation.notes}`,
    );
    // Do not persist an unverified remote URL. In particular, never disturb a
    // user-selected or previously validated primary image.
    return;
  }

  const path = imageStorageKey(restaurantId, imageUrl);
  const { error } = await supabase.storage
    .from("restaurant-photos")
    .upload(path, fetched.bytes, {
      contentType: fetched.contentType,
      upsert: true,
    });
  if (error) {
    throw new Error(`Image upload failed: ${error.message}`);
  }

  const publicUrl = `${
    Deno.env.get("SUPABASE_URL")
  }/storage/v1/object/public/restaurant-photos/${path}`;
  await setPrimaryImage(
    supabase,
    restaurantId,
    publicUrl,
    imageUrl,
    qualityScore,
  );
}
