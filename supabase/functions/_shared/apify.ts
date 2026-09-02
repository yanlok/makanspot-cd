// Instagram-native field mapping.
// No TikTok fields — this module handles only Instagram scraper records.

export interface IgRecord {
  // Instagram post fields (hashtag/location scraper)
  url?: string;
  ownerUsername?: string;
  caption?: string | { text?: string };
  displayUrl?: string;
  likesCount?: number;
  commentsCount?: number;
  timestamp?: string;
  code?: string;
  inputUrl?: string;
  parentData?: Record<string, unknown>;
  image_versions2?: { candidates?: Array<{ url?: string }> };
  like_count?: number;
  comment_count?: number;
  taken_at?: number | string;
  user?: { username?: string; pk?: string | number };
  location?: { pk?: string | number; id?: string | number; name?: string };
  // Instagram identity fields
  locationId?: string;
  locationName?: string;
  ownerId?: string;
  // Instagram place-search fields (instagram-search-scraper, searchType=place)
  location_id?: string;
  lat?: number;
  lng?: number;
  location_address?: string;
  location_city?: string;
  category?: string;
  price_range?: string;
  phone?: string;
  hours?: unknown;
  slug?: string;
  name?: string;
  ig_business?: unknown;
  posts?: Array<Record<string, unknown>>;
  searchTerm?: string;
  // Hashtag array (can be strings or objects)
  hashtags?: Array<string | { name?: string }>;
  // Catch-all
  [key: string]: unknown;
}

export interface StagingRow {
  platform: string;
  external_post_id: string;
  post_url: string | null;
  author_username: string | null;
  caption: string | null;
  cover_url: string | null;
  hashtags: string[];
  likes: number;
  comments: number;
  views: number;
  media_urls: string[];
  posted_at: string | null;
  location_id: string | null;
  location_name: string | null;
  source_query: string | null;
  status: "pending";
}

export interface PlaceCandidate {
  platform: string;
  external_id: string | null;
  name: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  city: string | null;
  category: string | null;
  price_range: string | null;
  phone: string | null;
  hours: unknown;
  slug: string | null;
  url: string | null;
  search_term: string | null;
  posts: IgRecord[];
}

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

function object(v: unknown): Record<string, unknown> | null {
  return !!v && typeof v === "object" ? v as Record<string, unknown> : null;
}

function stringValue(v: unknown): string | null {
  return typeof v === "string" && v.trim() ? v.trim() : null;
}

function locationIdFromUrl(value: unknown): string | null {
  const url = stringValue(value);
  return url?.match(/\/explore\/locations\/(\d+)/)?.[1] ?? null;
}

/** Extract the external post ID from an IG post URL. */
function extractPostId(url: string): string {
  // Instagram URLs: /p/CODE/ or /reel/CODE/
  const match = url.match(/\/(?:p|reel)\/([A-Za-z0-9_-]+)/);
  if (match) return match[1];
  // Fallback: use the full URL path as ID
  try {
    const u = new URL(url);
    return u.pathname.replace(/^\/+/, "").replace(/\/+$/, "");
  } catch {
    return url;
  }
}

/** Normalize hashtags from Apify's mixed format (strings or {name} objects). */
function normalizeHashtags(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((h) => (typeof h === "string" ? h : h?.name))
    .filter((h): h is string => !!h);
}

/**
 * Map a single raw Instagram Apify record into a staging row.
 * Returns null if the record has no usable dedup key.
 */
export function toStagingRow(
  rec: IgRecord,
  sourceQuery: string | null = null,
): StagingRow | null {
  const parent = object(rec.parentData);
  const code = stringValue(rec.code);
  const rawUrl = stringValue(rec.url);
  const postUrl = rawUrl && /\/(?:p|reel)\//.test(rawUrl) ? rawUrl : null;
  const rawInputUrl = stringValue(rec.inputUrl);
  const inputPostUrl = rawInputUrl && /\/(?:p|reel)\//.test(rawInputUrl)
    ? rawInputUrl
    : null;
  const url = postUrl ?? inputPostUrl ??
    (code ? `https://www.instagram.com/p/${code}/` : "");
  if (!url) return null;

  // Skip hashtag explore pages
  if (url.includes("/explore/tags/")) return null;

  const postId = extractPostId(url);
  if (!postId) return null;

  const captionObject = object(rec.caption);
  const caption = typeof rec.caption === "string"
    ? rec.caption
    : stringValue(captionObject?.text);
  const tags = normalizeHashtags(rec.hashtags);
  if (tags.length === 0 && caption) {
    tags.push(
      ...Array.from(
        caption.matchAll(/#([\p{L}\p{N}_]+)/gu),
        (match) => match[1],
      ),
    );
  }
  const candidates = object(rec.image_versions2)?.candidates;
  const nestedImages = Array.isArray(candidates)
    ? candidates.map((candidate) => stringValue(object(candidate)?.url)).filter(
      (url): url is string => !!url,
    )
    : [];
  const coverUrl = stringValue(rec.displayUrl) ?? nestedImages[0] ?? null;
  const nestedLocation = object(rec.location);
  const parentLocation = object(parent?.location);
  const locationId = stringValue(rec.locationId) ??
    stringValue(
      nestedLocation?.pk != null ? String(nestedLocation.pk) : null,
    ) ??
    stringValue(
      nestedLocation?.id != null ? String(nestedLocation.id) : null,
    ) ??
    stringValue(
      parent?.location_id != null ? String(parent.location_id) : null,
    ) ??
    stringValue(
      parentLocation?.pk != null ? String(parentLocation.pk) : null,
    ) ??
    locationIdFromUrl(parent?.inputUrl) ?? locationIdFromUrl(rawInputUrl);
  const nestedUser = object(rec.user);
  const takenAt = rec.taken_at;
  const postedAt = rec.timestamp ??
    (typeof takenAt === "number"
      ? new Date(takenAt * 1000).toISOString()
      : stringValue(takenAt));

  return {
    platform: "instagram",
    external_post_id: postId,
    post_url: url,
    author_username: rec.ownerUsername ?? stringValue(nestedUser?.username) ??
      null,
    caption,
    cover_url: coverUrl,
    hashtags: tags,
    likes: num(rec.likesCount ?? rec.like_count),
    comments: num(rec.commentsCount ?? rec.comment_count),
    views: 0, // Instagram hashtag/location scrapers don't expose view counts
    media_urls: coverUrl
      ? [coverUrl, ...nestedImages.filter((url) => url !== coverUrl)]
      : nestedImages,
    posted_at: postedAt ?? null,
    location_id: locationId,
    location_name: rec.locationName ?? stringValue(nestedLocation?.name) ??
      stringValue(parentLocation?.name),
    source_query: sourceQuery,
    status: "pending",
  };
}

/**
 * Map a single place-search item into a structured candidate.
 * Returns null unless the record carries a location identity or name+coords.
 */
export function toPlaceCandidate(rec: IgRecord): PlaceCandidate | null {
  const externalId = rec.location_id != null ? String(rec.location_id) : null;
  const name = rec.name != null ? String(rec.name) : null;
  const lat = typeof rec.lat === "number" && Number.isFinite(rec.lat)
    ? rec.lat
    : null;
  const lng = typeof rec.lng === "number" && Number.isFinite(rec.lng)
    ? rec.lng
    : null;

  if (!externalId && !(name && lat !== null && lng !== null)) return null;

  const slug = rec.slug != null ? String(rec.slug) : null;
  const url = externalId
    ? `https://www.instagram.com/explore/locations/${externalId}/${
      slug ? `${slug}/` : ""
    }`
    : (rec.url != null ? String(rec.url) : null);

  return {
    platform: "instagram",
    external_id: externalId,
    name,
    latitude: lat,
    longitude: lng,
    address: rec.location_address != null ? String(rec.location_address) : null,
    city: rec.location_city != null ? String(rec.location_city) : null,
    category: rec.category != null ? String(rec.category) : null,
    price_range: rec.price_range != null ? String(rec.price_range) : null,
    phone: rec.phone != null ? String(rec.phone) : null,
    hours: rec.hours ?? null,
    slug,
    url,
    search_term: rec.searchTerm != null ? String(rec.searchTerm) : null,
    posts: Array.isArray(rec.posts)
      ? rec.posts
        .filter((p): p is Record<string, unknown> =>
          !!p && typeof p === "object"
        )
        .map((p) => p as IgRecord)
      : [],
  };
}

/**
 * Map a place candidate's posts into staging rows, injecting the place's
 * location identity into posts that don't carry their own.
 */
export function placePostsToRows(place: PlaceCandidate): StagingRow[] {
  const rows: StagingRow[] = [];
  for (const post of place.posts) {
    const inheritedPost: IgRecord = {
      ...post,
      parentData: {
        inputUrl: place.url,
        location_id: place.external_id,
        location: { pk: place.external_id, name: place.name },
        ...(post.parentData ?? {}),
      },
    };
    const row = toStagingRow(inheritedPost, place.search_term);
    if (!row) continue;
    // The discovery result is the canonical parent. Nested post/parentData
    // metadata can be stale or refer to a different location and must not win.
    if (place.external_id) {
      row.location_id = place.external_id;
    }
    if (!row.location_name && place.name) row.location_name = place.name;
    rows.push(row);
  }
  return rows;
}

const FOOD_PLACE_SIGNALS = [
  "restaurant",
  "restoran",
  "cafe",
  "café",
  "coffee",
  "food",
  "eatery",
  "bakery",
  "dessert",
  "bistro",
  "bar & grill",
  "hawker",
  "kopitiam",
  "mamak",
  "warung",
  "gerai",
  "stall",
  "kitchen",
  "pizza",
  "burger",
  "noodle",
  "nasi",
  "makan",
  "sushi",
  "ramen",
  "seafood",
  "steak",
  "tea room",
  "ice cream",
];

const NON_FOOD_PLACE_SIGNALS = [
  "airport",
  "apartment",
  "beauty",
  "clinic",
  "college",
  "condominium",
  "fitness",
  "gym",
  "hospital",
  "hotel",
  "mosque",
  "office",
  "park",
  "residential",
  "salon",
  "school",
  "shopping mall",
  "spa",
  "stadium",
  "university",
  "worship",
];

/**
 * Require positive food evidence in the place metadata or embedded posts.
 * Unknown/empty categories alone are not enough to create canonical data.
 */
export function isLikelyFoodPlace(
  place: Pick<PlaceCandidate, "name" | "category" | "posts">,
): boolean {
  const text = `${place.name ?? ""} ${place.category ?? ""}`.toLowerCase();
  const positiveMetadata = FOOD_PLACE_SIGNALS.some((signal) =>
    text.includes(signal)
  );
  const embeddedEvidence = (place.posts ?? []).some((post) => {
    const hashtags = Array.isArray(post.hashtags)
      ? post.hashtags.map((tag) =>
        typeof tag === "string" ? tag : tag?.name ?? ""
      ).join(" ")
      : "";
    const postText = `${post.caption ?? ""} ${
      post.locationName ?? ""
    } ${hashtags}`.toLowerCase();
    return FOOD_PLACE_SIGNALS.some((signal) => postText.includes(signal));
  });
  // Explicit non-food metadata always wins; its embedded posts may still be
  // staged, but the mall/hotel/etc. must not become a canonical restaurant.
  if (NON_FOOD_PLACE_SIGNALS.some((signal) => text.includes(signal))) {
    return false;
  }
  if (!positiveMetadata && !embeddedEvidence) return false;
  return true;
}

export function shouldQueueLocationPosts(opts: {
  hasPrimary: boolean;
  hasEmbeddedCover: boolean;
  exactLocationUrl: string | null;
}): boolean {
  return !opts.hasPrimary && !opts.hasEmbeddedCover &&
    !!opts.exactLocationUrl &&
    /\/explore\/locations\/\d+\//.test(opts.exactLocationUrl);
}

export function boundLocationPostTargets<T>(targets: T[]): T[] {
  return targets.slice(0, 1);
}

export function boundLocationPostItems<T>(
  items: T[],
  alreadyProcessed: number,
): T[] {
  return items.slice(0, Math.max(0, 3 - alreadyProcessed));
}

export function applyAuthoritativeLocation(
  row: StagingRow,
  locationId: string,
): StagingRow {
  row.location_id = locationId;
  return row;
}
