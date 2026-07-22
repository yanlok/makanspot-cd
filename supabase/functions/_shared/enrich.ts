/// <reference path="./deno.d.ts" />
// Enrichment helpers: turn a raw scraped caption into a structured restaurant.
//
// Two external calls, both configured via Edge Function secrets:
//   OPENAI_API_KEY        -> LLM venue extraction from free-text captions
//   GOOGLE_GEOCODING_KEY  -> resolve name/address into lat/long + clean address
//
// Both are defensive: if a key is missing or the call fails, we degrade
// gracefully so the row can still fall back to the admin review queue.

export interface VenueExtraction {
  is_restaurant: boolean;
  name: string | null;
  address: string | null;
  city: string | null;
  cuisine: string | null;
  price_range: "$" | "$$" | "$$$" | "$$$$" | null;
  description: string | null;
  categories: string[]; // subset of CATEGORY_TAXONOMY
  confidence: number; // 0..1
}

export interface GeoResult {
  latitude: number;
  longitude: number;
  formatted_address: string;
}

/**
 * Fixed category taxonomy. The LLM must map each venue to a subset of these,
 * and the keyword fallback maps to the same list. Keeping it fixed (rather than
 * free-form auto-created names) means the app's category filter stays clean and
 * duplicate-free. Names align with the existing seeded categories.
 */
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
  `You extract restaurant/cafe/eatery details from Malaysian TikTok & Instagram food captions.
Return STRICT JSON only, matching this TypeScript type:
{
  "is_restaurant": boolean,   // false if the caption is not about one specific eatery (e.g. a generic listicle, a food court with no name)
  "name": string | null,      // the venue name only, no emojis/hashtags
  "address": string | null,   // full street address if present in the caption
  "city": string | null,      // e.g. "Kuala Lumpur", "Petaling Jaya"
  "cuisine": string | null,   // e.g. "Middle Eastern", "Chinese", "Cafe"
  "price_range": "$" | "$$" | "$$$" | "$$$$" | null,
  "description": string | null, // one clean sentence describing the food/spot
  "categories": string[],     // 1-3 items chosen ONLY from this list: ["Malay","Chinese","Indian","Mamak","Cafe","Western","Japanese","Korean","Thai","Middle Eastern","Seafood","Dessert & Bakery","Fast Food","Street Food","Vegetarian"]
  "confidence": number        // 0..1, your confidence that name+location are correct
}
Rules: never invent an address that is not implied by the caption. Only use categories from the given list; if none fit, return []. If unsure, lower the confidence. Output JSON with no markdown fences.`;

/** Ask the LLM to extract a structured venue from a caption. */
export async function extractVenue(
  caption: string,
  hashtags: string[],
  author: string | null,
): Promise<VenueExtraction> {
  // Provider-agnostic (OpenAI-compatible) config. For DeepSeek set:
  //   LLM_API_KEY   = <your deepseek key>
  //   LLM_BASE_URL  = https://api.deepseek.com
  //   LLM_MODEL     = deepseek-chat
  // Defaults keep OpenAI working (OPENAI_* vars still honoured as fallback).
  const apiKey = Deno.env.get("LLM_API_KEY") ?? Deno.env.get("OPENAI_API_KEY");
  const baseUrl = (Deno.env.get("LLM_BASE_URL") ?? "https://api.openai.com/v1")
    .replace(/\/+$/, "");
  const model = Deno.env.get("LLM_MODEL") ?? Deno.env.get("OPENAI_MODEL") ??
    "gpt-4o-mini";

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
  };

  if (!apiKey) return fallback;

  const userContent =
    `Author: @${author ?? "unknown"}\nHashtags: ${hashtags.join(", ")}\n\nCaption:\n${caption}`;

  try {
    const resp = await fetch(`${baseUrl}/chat/completions`, {
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
    });

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
    };
  } catch (_e) {
    return fallback;
  }
}

/** Resolve a venue name/address into coordinates via Google Geocoding. */
export async function geocode(
  name: string | null,
  address: string | null,
  city: string | null,
): Promise<GeoResult | null> {
  const apiKey = Deno.env.get("GOOGLE_GEOCODING_KEY");
  if (!apiKey) return null;

  const query = [name, address, city, "Malaysia"]
    .filter((p) => p && p.trim().length > 0)
    .join(", ");
  if (!query) return null;

  try {
    const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
    url.searchParams.set("address", query);
    url.searchParams.set("region", "my");
    url.searchParams.set("key", apiKey);

    const resp = await fetch(url.toString());
    if (!resp.ok) return null;
    const data = await resp.json();
    const result = data?.results?.[0];
    if (!result?.geometry?.location) return null;

    return {
      latitude: result.geometry.location.lat,
      longitude: result.geometry.location.lng,
      formatted_address: result.formatted_address ?? address ?? query,
    };
  } catch (_e) {
    return null;
  }
}

/** Heuristic hidden-gem detection from hashtags + caption. */
export function isHiddenGem(hashtags: string[], caption: string): boolean {
  const tags = hashtags.map((h) => h.toLowerCase());
  if (tags.some((t) => t.includes("hiddengem"))) return true;
  return /hidden\s*(gem|spot)/i.test(caption);
}

/** Popularity score in 0..100 derived from engagement (log-scaled views). */
export function popularityScore(
  playCount: number,
  diggCount: number,
  shareCount: number,
): number {
  const views = Math.max(0, playCount);
  const viewScore = Math.min(70, Math.round((Math.log10(views + 1) / 6) * 70));
  const engageScore = Math.min(
    30,
    Math.round(((diggCount + shareCount * 2) / 5000) * 30),
  );
  return Math.min(100, viewScore + engageScore);
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

const TAXONOMY_LOWER = new Map(
  CATEGORY_TAXONOMY.map((c) => [c.toLowerCase(), c]),
);

/** Keep only valid taxonomy names (case-insensitive), de-duplicated. */
export function normalizeCategories(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  const out: string[] = [];
  for (const item of input) {
    const canonical = TAXONOMY_LOWER.get(String(item).trim().toLowerCase());
    if (canonical && !out.includes(canonical)) out.push(canonical);
  }
  return out;
}

// keyword -> taxonomy category, scanned against cuisine + name + hashtags.
const CATEGORY_KEYWORDS: Array<[string, string]> = [
  ["nasi lemak", "Malay"],
  ["nasi", "Malay"],
  ["warung", "Malay"],
  ["warong", "Malay"],
  ["gerai", "Malay"],
  ["sarapan", "Malay"],
  ["melayu", "Malay"],
  ["malay", "Malay"],
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

/**
 * Fallback classifier when the LLM extraction has no categories (e.g. reused
 * extractions from before categories existed). Scans cuisine + name + hashtags.
 */
export function deriveCategories(
  cuisine: string | null,
  name: string | null,
  hashtags: string[],
): string[] {
  const haystack = [
    cuisine ?? "",
    name ?? "",
    hashtags.join(" "),
  ].join(" ").toLowerCase();

  const out: string[] = [];
  for (const [keyword, category] of CATEGORY_KEYWORDS) {
    if (haystack.includes(keyword) && !out.includes(category)) {
      out.push(category);
    }
  }
  return out.slice(0, 3);
}

// ---------------------------------------------------------------------------
// Google Places photos (re-hosting source)
// ---------------------------------------------------------------------------

function placesKey(): string | undefined {
  return Deno.env.get("GOOGLE_PLACES_KEY") ??
    Deno.env.get("GOOGLE_GEOCODING_KEY");
}

/** Structured Google Places profile used to enrich a restaurant row. */
export interface PlaceDetails {
  photoReference: string | null;
  phoneNumber: string | null;
  rating: number | null; // 0..5
  reviewCount: number | null;
  operatingHours: { weekday_text?: string[]; periods?: unknown[] } | null;
}

/**
 * Look up a venue on Google Places (biased to its coordinates) and return its
 * photo reference plus profile fields (phone, rating, review count, opening
 * hours). Returns null when Places is unavailable; individual fields are null
 * when the place has no such data.
 */
export async function fetchPlaceDetails(
  name: string,
  latitude: number,
  longitude: number,
): Promise<PlaceDetails | null> {
  const apiKey = placesKey();
  if (!apiKey) return null;
  try {
    // 1. Resolve the venue to a place_id (and grab a photo reference).
    const findUrl = new URL(
      "https://maps.googleapis.com/maps/api/place/findplacefromtext/json",
    );
    findUrl.searchParams.set("input", `${name} Malaysia`);
    findUrl.searchParams.set("inputtype", "textquery");
    findUrl.searchParams.set("fields", "place_id,photos");
    findUrl.searchParams.set(
      "locationbias",
      `circle:2000@${latitude},${longitude}`,
    );
    findUrl.searchParams.set("key", apiKey);

    const findResp = await fetch(findUrl.toString());
    if (!findResp.ok) return null;
    const findData = await findResp.json();
    const candidate = findData?.candidates?.[0];
    const photoReference: string | null =
      typeof candidate?.photos?.[0]?.photo_reference === "string"
        ? candidate.photos[0].photo_reference
        : null;
    const placeId: string | undefined = candidate?.place_id;

    let phoneNumber: string | null = null;
    let rating: number | null = null;
    let reviewCount: number | null = null;
    let operatingHours: PlaceDetails["operatingHours"] = null;

    // 2. Fetch the profile fields via Place Details (needs the place_id).
    if (placeId) {
      const detUrl = new URL(
        "https://maps.googleapis.com/maps/api/place/details/json",
      );
      detUrl.searchParams.set("place_id", placeId);
      detUrl.searchParams.set(
        "fields",
        "formatted_phone_number,international_phone_number,rating,user_ratings_total,opening_hours",
      );
      detUrl.searchParams.set("key", apiKey);

      const detResp = await fetch(detUrl.toString());
      if (detResp.ok) {
        const res = (await detResp.json())?.result;
        if (res) {
          phoneNumber = res.formatted_phone_number ??
            res.international_phone_number ?? null;
          rating = typeof res.rating === "number" ? res.rating : null;
          reviewCount = typeof res.user_ratings_total === "number"
            ? res.user_ratings_total
            : null;
          if (res.opening_hours) {
            operatingHours = {
              weekday_text: res.opening_hours.weekday_text,
              periods: res.opening_hours.periods,
            };
          }
        }
      }
    }

    return { photoReference, phoneNumber, rating, reviewCount, operatingHours };
  } catch (_e) {
    return null;
  }
}

/** Download the actual photo bytes for a Places photo reference. */
export async function fetchPlacePhotoBytes(
  photoReference: string,
  maxWidth = 1024,
): Promise<{ bytes: Uint8Array; contentType: string } | null> {
  const apiKey = placesKey();
  if (!apiKey) return null;
  try {
    const url = new URL("https://maps.googleapis.com/maps/api/place/photo");
    url.searchParams.set("maxwidth", String(maxWidth));
    url.searchParams.set("photo_reference", photoReference);
    url.searchParams.set("key", apiKey);

    // The endpoint 302-redirects to the actual image; fetch follows it.
    const resp = await fetch(url.toString());
    if (!resp.ok) return null;
    const contentType = resp.headers.get("content-type") ?? "image/jpeg";
    if (!contentType.startsWith("image/")) return null;
    const bytes = new Uint8Array(await resp.arrayBuffer());
    if (bytes.length === 0) return null;
    return { bytes, contentType };
  } catch (_e) {
    return null;
  }
}

/** Download arbitrary image bytes from a URL (e.g. a still-valid cover URL). */
export async function fetchImageBytes(
  imageUrl: string,
): Promise<{ bytes: Uint8Array; contentType: string } | null> {
  try {
    const resp = await fetch(imageUrl);
    if (!resp.ok) return null;
    const contentType = resp.headers.get("content-type") ?? "image/jpeg";
    if (!contentType.startsWith("image/")) return null;
    const bytes = new Uint8Array(await resp.arrayBuffer());
    if (bytes.length === 0) return null;
    return { bytes, contentType };
  } catch (_e) {
    return null;
  }
}
