// Types + mapping for Apify TikTok/Instagram scraper records.
//
// The scraper emits flattened dotted keys (e.g. "videoMeta.coverUrl"), so we
// read them defensively and normalise into our snake_case staging columns.

export interface ApifyRecord {
  "videoMeta.coverUrl"?: string;
  "videoMeta.duration"?: number;
  "authorMeta.name"?: string;
  text?: string;
  webVideoUrl?: string;
  createTimeISO?: string;
  diggCount?: number;
  shareCount?: number;
  playCount?: number;
  commentCount?: number;
  isAd?: boolean;
  hashtags?: Array<{ id?: string; name?: string; title?: string; cover?: string }>;
  // Instagram variants may differ; keep index access open.
  [key: string]: unknown;
}

export interface StagingRow {
  platform: string;
  web_video_url: string;
  author_name: string | null;
  caption: string | null;
  cover_url: string | null;
  hashtags: unknown;
  digg_count: number;
  share_count: number;
  play_count: number;
  comment_count: number;
  video_duration: number;
  is_ad: boolean;
  posted_at: string | null;
  raw: ApifyRecord;
  status: "pending";
}

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

/** Detect the platform from the post URL; defaults to tiktok. */
export function detectPlatform(rec: ApifyRecord): string {
  const url = (rec.webVideoUrl ?? "").toLowerCase();
  if (url.includes("instagram.com")) return "instagram";
  if (url.includes("tiktok.com")) return "tiktok";
  return "tiktok";
}

/** Map a single raw Apify record into a staging row. Returns null if unusable. */
export function toStagingRow(rec: ApifyRecord): StagingRow | null {
  const webVideoUrl = rec.webVideoUrl?.trim();
  if (!webVideoUrl) return null; // no stable dedup key -> skip

  return {
    platform: detectPlatform(rec),
    web_video_url: webVideoUrl,
    author_name: rec["authorMeta.name"] ?? null,
    caption: rec.text ?? null,
    cover_url: rec["videoMeta.coverUrl"] ?? null,
    hashtags: Array.isArray(rec.hashtags)
      ? rec.hashtags.filter((h) => h && h.name).map((h) => h.name)
      : [],
    digg_count: num(rec.diggCount),
    share_count: num(rec.shareCount),
    play_count: num(rec.playCount),
    comment_count: num(rec.commentCount),
    video_duration: num(rec["videoMeta.duration"]),
    is_ad: rec.isAd === true,
    posted_at: rec.createTimeISO ?? null,
    raw: rec,
    status: "pending",
  };
}
