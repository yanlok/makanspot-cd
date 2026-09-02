# Scraped Post Pipeline — Architecture & Design

## Why we built this

MakanSpot's restaurant data comes from social media — TikTok and Instagram posts
where people share food discoveries. Instead of manually entering restaurants one
by one, we built an automated pipeline that:

1. **Ingests** raw scraper data (from Apify) into a staging table
2. **Enriches** each post using AI + Google Geocoding to extract a structured restaurant
3. **Merges** multiple posts about the same restaurant into one entry with aggregated stats

The result: a constantly growing restaurant directory powered by real social buzz.

> **Note:** Google Places API (phone, hours, ratings, photos) was originally part of this
> pipeline but was removed due to high costs. Only Geocoding API remains — it's the only
> paid Google API in use, and its free tier (~$200/month credit) covers roughly 42,900
> requests. We've set a daily limit of 333 geocoding requests to stay under 10K/month.
> See the [Cost analysis](#geocoding-cost-analysis) section for details.

---

## High-level flow

```
Raw Apify export (JSON)
        │
        ▼
┌──────────────────────────────┐
│  Ingest                       │  ingest-scraped-posts
│  "Land raw posts in staging"  │
│  • Field mapping              │
│  • Dedup by video URL         │
│  • Effectively idempotent     │
└─────────┬────────────────────┘
          │  scraped_posts table (status = "pending")
          ▼
┌──────────────────────────────┐
│  Enrich                       │  enrich-scraped-posts
│  "Post → Restaurant"          │
│  • LLM venue extraction       │
│  • Google Geocoding           │
│  • Category classification    │
│  • Merge-or-insert logic      │
└─────────┬────────────────────┘
          │  restaurants table (is_approved = false)
          ▼
     Admin reviews & approves
          │
          ▼
     Public restaurant listing
```

---

## Step 1: Ingest (`ingest-scraped-posts`)

### What it does

A Supabase Edge Function that accepts a raw Apify scraper export, maps the flat
key-value fields into our `scraped_posts` table schema, and inserts them.

### Key design decisions

**Dedup by `web_video_url`.** Every social video has a unique URL. If we re-import
the same dataset, existing rows are untouched (`ignoreDuplicates: true`). This makes
re-imports safe — you can drop the same file twice without creating duplicates.

**Lossless raw storage.** The entire original Apify record is saved in the `raw`
JSONB column. This means enrichment logic can change later and we can re-process
old posts without re-scraping.

**Status = `"pending"`.** Fresh rows start as pending, waiting for the enrichment
step to pick them up.

### Table structure

```sql
scraped_posts (
  id                  BIGINT PRIMARY KEY,
  platform            TEXT,           -- "tiktok" | "instagram"
  web_video_url       TEXT UNIQUE,    -- dedup key
  author_name         TEXT,
  caption             TEXT,
  cover_url           TEXT,           -- ephemeral signed URL
  hashtags            JSONB,
  digg_count / share_count / play_count / comment_count / video_duration / is_ad / posted_at,
  raw                 JSONB,          -- original Apify record (for re-processing)
  status              TEXT,           -- pending → processing → promoted | skipped | failed
  extraction          JSONB,          -- LLM venue extraction result (cached on re-run)
  extraction_confidence NUMERIC(3,2), -- 0.00 – 1.00 (see "Key Metrics" below)
  promoted_restaurant_id BIGINT REFERENCES restaurants,
  error               TEXT,
  ingested_at / processed_at TIMESTAMPTZ
)
```

---

## Step 2: Enrich (`enrich-scraped-posts`)

This is the core of the pipeline — turning a raw social post into a structured
restaurant. It picks up `"pending"` rows and processes each one through several
stages.

### Stage A — LLM venue extraction

We send the post's caption + hashtags + author to an LLM (configurable, defaults
to `gpt-4o-mini`) with a strict prompt that asks:

> "Is this a single identifiable restaurant/cafe/eatery? If yes, extract its name,
> address, city, cuisine, price range, description, and categories from a fixed
> taxonomy."

The LLM returns JSON:

```json
{
  "is_restaurant": true,
  "name": "Village Park Restaurant",
  "address": "5 Jalan SS21/37",
  "city": "Petaling Jaya",
  "cuisine": "Malay",
  "price_range": "$$",
  "description": "Famous for nasi lemak with creamy sambal",
  "categories": ["Malay"],
  "confidence": 0.92
}
```

**Not a restaurant?** If the post is a listicle, a recipe, or a food court without
a name, `is_restaurant` is `false` and the row is **skipped** — we don't waste
Google API calls on it.

### Stage B — Google Geocoding

Takes the extracted name + address + city, appends "Malaysia", and calls Google
Geocoding to get:
- Latitude / Longitude
- A clean formatted address

If geocoding fails (e.g. venue name is too vague), the row is **failed** — it
needs a human to look at it.

### Stage C — Category classification

Categories come from a **fixed taxonomy** (not free-form). This was a deliberate
design choice:

> A fixed taxonomy keeps the app's category filter clean and predictable. If we
> let the LLM invent categories, we'd end up with "Malay food", "Malaysian food",
> "Malay cuisine" as separate filters — a mess.

| Taxonomies |
|---|
| Malay, Chinese, Indian, Mamak, Cafe, Western |
| Japanese, Korean, Thai, Middle Eastern |
| Seafood, Dessert & Bakery, Fast Food, Street Food |
| Vegetarian, Hidden Gem (auto-detected) |

Two sources, tried in order:
1. **LLM classification** (preferred) — the AI picks from the taxonomy
2. **Keyword fallback** — scans cuisine + name + hashtags against a keyword map
   (e.g. "sushi" → Japanese, "nasi lemak" → Malay, "burger" → Western)

"Hidden Gem" is auto-detected from `#hiddengem` hashtag or "hidden gem" in caption.

### Stage D — Merge-or-insert logic

This is where we decide: does this post refer to a restaurant already in our DB?

**Search window:** ~13km radius from the venue's coordinates.

| Name match type | Allow distance | Rationale |
|---|---|---|
| Exact name | Anywhere in 13km | Same-name geocodes drift, so give slack |
| Prefix (≥5 chars match, e.g. "Village Park" ≈ "Village Park Restaurant") | ~450m | Conservative — must be very close |

**If a match is found → merge:**

```
popularity_score   += this_post's score
is_trending        |= this_post's trending flag
is_hidden_gem      |= this_post's hidden gem flag
source_post_count  += 1
```

If this post's video has more plays than the current top video:
- Promote it as the new primary post (`post_url`, `social_media_source`)
- Update `description` from LLM extraction if available

**If no match → insert a new restaurant:**

Creates a restaurant row with `is_approved = false`. It won't appear in the public
app until an admin approves it. Only LLM-extracted data and geocoding results are
stored — no Google Places phone/rating/hours/photo data is attached.

### Stage E — Image fallback chain

The original Google Places photo re-hosting was stripped out due to cost. In its
place the pipeline runs a 4-tier image chain (`_shared/enrich.ts`) during the
metrics step, for every affected restaurant that does **not** already have a
primary image:

1. **Post image** — the best `cover_url` across the restaurant's linked posts
   (`selectBestImageCandidate`), validated by a vision LLM
   (`_shared/image-validation.ts`, tuned to accept anything restaurant-related:
   food, promos, menus with branding, influencer-at-venue shots) and re-hosted
   to `restaurant-photos/` in Supabase Storage.
2. **Instagram profile pic** — the post owner's `profile_pic_url` from the
   Apify dataset (requires `addParentData: true`).
3. **Website OG image** — `og:image` from the restaurant's website.
4. **Category placeholder** — a generated SVG under
   `restaurant-photos/placeholders/<category>.svg` (quality score 0.1).

Every restaurant must end up with a primary image; `restaurants_no_image` in
the run stats counts any that somehow don't. `backfill-images` re-runs the same
shared chain over a list of restaurant IDs to repair placeholder primaries.
`restaurant_images` is kept strictly 1-1 with `restaurants`: the app reads only
the primary row, so when a new image is promoted every other row for the
restaurant is deleted, and a candidate that loses the score comparison is
deleted rather than lingering as non-primary.
Ephemeral Instagram CDN URLs are never stored as `image_url` — the re-hosted
storage URL is the canonical `image_url` and the CDN URL is kept in
`source_url`.

---

## Key metrics: how scores work

### `extraction_confidence` (0.00 – 1.00)

**What it is:** The LLM's self-reported confidence that its extraction is correct.
It's returned as part of the LLM's JSON response — we ask the AI to rate its own
certainty.

**Why it matters:** The `minConfidence` parameter (default 0.5) sets a threshold:

- `confidence >= 0.5` → proceed to geocoding and promotion
- `confidence < 0.5` → mark as **failed**, leave for admin review

This prevents the pipeline from auto-creating restaurants when the AI is unsure.
If you want more aggressive auto-promotion, lower `minConfidence`; if you want
fewer junk entries, raise it.

### `popularity_score` (0 – 100, per post, accumulated)

**What it is:** A score from 0–100 that measures how much social buzz a social
media post generated. It feeds into the restaurant's overall ranking — more buzz
= higher in the list.

**Source code:** [`popularityScore()`](file:///c:/Users/tayer/StudioProjects/makanspot/supabase/functions/_shared/enrich.ts#L188-L201)
in `supabase/functions/_shared/enrich.ts`

---

#### Formula

The score has two parts added together:

```typescript
function popularityScore(playCount, diggCount, shareCount) {
  const viewScore   = Math.min(70, Math.round((Math.log10(playCount + 1) / 6) * 70));
  const engageScore = Math.min(30, Math.round(((diggCount + shareCount * 2) / 5000) * 30));
  return Math.min(100, viewScore + engageScore);
}
```

#### Part 1: View Score (max 70 points)

Uses **log₁₀** to make the scale logarithmic rather than linear:

```
viewScore = log₁₀(playCount + 1) / 6 × 70
```

Why `÷ 6`? Because log₁₀(1,000,000) ≈ 6, so a video with 1 million views
hits the maximum of 70 points.

| Play count | log₁₀ calculation | viewScore |
|---|---|---|
| 10 | log₁₀(11) ≈ 1.04 → 1.04/6 × 70 | ~12 |
| 100 | log₁₀(101) ≈ 2.00 → 2.00/6 × 70 | ~23 |
| 1,000 | log₁₀(1,001) ≈ 3.00 → 3.00/6 × 70 | ~35 |
| 10,000 | log₁₀(10,001) ≈ 4.00 → 4.00/6 × 70 | ~47 |
| 100,000 | log₁₀(100,001) ≈ 5.00 → 5.00/6 × 70 | ~58 |
| 1,000,000 | log₁₀(1,000,001) ≈ 6.00 → 6.00/6 × 70 | **70 (max)** |

The gap between 10 and 100 plays (~11 pts) is the same as between 100,000 and
1,000,000 plays (~12 pts) — each **10× increase** adds roughly the same increment.

#### Part 2: Engagement Score (max 30 points)

```
engageScore = (diggCount + shareCount × 2) / 5000 × 30
```

- **Shares count double** (×2) — sharing is a stronger signal than liking; it
  means someone thought the content was worth their followers' time
- **÷ 5000** — you need about 5,000 weighted interactions to max this portion

| Likes | Shares | Weighted Score<br>(Likes + Shares × 2) | Engage Score |
|:-----:|:------:|:----------------------------------:|:------------:|
| 100   | 0      | 100                                | ~1           |
| 500   | 0      | 500                                | ~3           |
| 1,000 | 50     | 1,100                              | ~7           |
| 2,000 | 200    | 2,400                              | ~14          |
| 5,000 | 0      | 5,000                              | **30 (Max)** |
| 500   | 2,250  | 5,000                              | **30 (Max)** |

#### Final score

```
final = Math.min(100, viewScore + engageScore)
```

Capped at 100. A post that goes viral in views but has low engagement still
falls short; a post with great engagement but few views also can't max out.

#### Worked examples

**Post A — modest neighbourhood spot:**
- 5,000 plays, 200 likes, 20 shares
- viewScore ≈ 37, engageScore ≈ 2 → **total ~39 / 100**

**Post B — trending discovery:**
- 85,000 plays, 4,200 likes, 600 shares
- viewScore ≈ 57, engageScore ≈ 16 → **total ~73 / 100**

**Post C — viral hit:**
- 2.5M plays, 80,000 likes, 12,000 shares
- viewScore = 70, engageScore = 30 → **total 100 / 100**

---

#### Why the formula is designed this way

| Choice | Why |
|---|---|
| **Logarithmic viewScale** | A video with 1K plays isn't "1,000× less popular" than a 1M-play video —
they exist in different leagues. Logarithmic scoring keeps all videos on a
comparable 0–70 scale. |
| **Shares × 2** | A share requires active endorsement;
a like is passive. Weighting shares double rewards genuinely recommendable
content. |
| **70/30 split** | Views measure reach; likes+shares measure
reaction. Giving views the larger share (70%) recognises that a restaurant

mentioned in a widely-seen video has real discovery value. |
| **Capped at 100** | Keeps the score intuitive — it's a percentage-like
number that's easy to reason about. |

---

#### How the score is used

**At creation time** — when a new restaurant is inserted from a single post:
```typescript
popularity_score: thisScore  // just the one post's score
```

**At merge time** — when multiple posts talk about the same restaurant:
```typescript
popularity_score: (match.popularity_score ?? 0) + thisScore
```

This means restaurants gain score **additively** as more social posts mention
them. A restaurant mentioned by 5 modest posts (~35 pts each) reaches ~175 pts
and outranks a restaurant with one viral hit (100 pts) that nobody else talks
about. This matches the real-world intuition: **word-of-mouth frequency** matters
as much as peak popularity.

---

## Status state machine

Each row in `scraped_posts` follows this lifecycle:

```
                         ┌──────────┐
        ingest           │          │
  ─────────────────────► │ pending  │
                         │          │
                         └────┬─────┘
                              │ enrich
                              ▼
              ┌───────────────┼───────────────┐
              │               │               │
          ┌───┴───┐      ┌───┴───┐      ┌───┴───┐
          │promoted│      │skipped│      │failed │
          │       │      │       │      │       │
          └───────┘      └───────┘      └───────┘
                                              │
                       (via action: "status"  │
                        with reset: true)     │
                                              │
                         ┌────────────────────┘
                         │
                         ▼
                      ┌──────────┐
                      │ pending  │   (reset by admin)
                      └──────────┘
```

| Status | Meaning |
|---|---|
| `pending` | Awaiting enrichment |
| `promoted` | ✓ Restaurant created or merged into |
| `skipped` | Not a restaurant post (listicle, recipe, etc.) |
| `failed` | AI or geocoding couldn't extract enough info |

---

## Extra operational modes

### Status check (`action: "status"`)

Reports counts per status plus the 15 most recent failed/skipped/promoted rows.
Also supports `reset: true` to move failed rows back to pending for retry.

### Backfill Places (`action: "backfill-places"`)

*Removed.* This mode previously fetched Google Places data (phone, hours, rating)
for existing restaurants that had missing fields. Since Places API is no longer
used, this action has been deleted from the pipeline.

### Reprocess (`action: "reprocess"`)

Deletes all scraped-sourced restaurants and resets their posts to `"pending"`.
The cached `extraction` JSONB is reused on re-run, so no LLM tokens are spent
on the extraction step — only geocoding is re-made.

---

## Geocoding cost analysis

### What we use

The pipeline calls the **Google Geocoding API** once per venue that passes AI
extraction + confidence threshold. Each call resolves a venue name + address into
coordinates (lat/lng) and a formatted address.

### What we removed

- **Google Places API** (Find Place + Place Details) — this was making 2+ calls per
  venue (find the place_id, then fetch phone/hours/rating + photo). **Removed.**
- **Google Places Photo API** — downloading photo bytes for re-hosting. **Removed.**
- **Supabase Storage photo uploads** — no longer needed since we don't re-host photos.
  **Removed.**

### Current cost picture

| API | Cost | Calls/month (capped at 333/day) | Monthly cost |
|---|---|---|---|
| Geocoding | $4.66 / 1K requests | ~10,000 | ~$46.60 → **$0** (covered by $200 free credit) |
| Total | | ~10,000 | **$0** |

The Google Maps Platform $200/month free credit covers all geocoding usage. We
will not exceed it at 10K calls/month.

### Why 333 calls/day?

- **333/day × 30 days ≈ 10,000 calls/month** — a safe cap that keeps us well under
  the free credit limit
- **In practice:** each enrichment batch processes `limit` posts (default 15).
  Not all posts become restaurants (some are skipped/failed). So you'd need ~30+ batches
  to hit 333 geocoding calls. That's plenty for a student project.
- **If you hit the cap mid-run**, rows stay as `"failed"` with error
  `"geocoding_failed"`. You can retry them the next day with
  `action: "status"` and `reset: true`.

### Is the current implementation efficient?

**Yes — it's minimal.** One geocode call per venue that clears the LLM check. No
batching waste, no retry loops, no redundant calls. The query is narrowed with
`region=my` (Malaysia) so Google doesn't waste time searching the whole world.

The only optimization to consider: if multiple posts in the same batch reference
**the exact same venue name**, we could cache geocoding results in-memory to avoid
redundant calls. Currently each post is processed independently.

---

## Important notes

- **New restaurants begin as drafts.** They land with `is_approved = false` and
  won't appear in the app until an admin approves them.
- **Duplicate posts are safe.** Same video URL = skipped on re-import.
- **Multiple posts → one restaurant.** We merge, not duplicate. This gives each
  restaurant an aggregated popularity score that reflects real social buzz.
- **Geocoding is the only Google API cost.** At ~$4.66/1K requests with the
  $200/month free credit, we get ~42,900 free geocoding requests per month.
  With the daily cap of 333 requests, we stay safely under 10K/month (~$0 cost).

---

## How to run

```bash
# Go to project root
cd c:\Users\tayer\StudioProjects\makanspot

# Full pipeline: ingest newest dataset + enrich
node scripts/run_pipeline.mjs "path/to/dataset.json"

# Or just use the newest file in /datasets
node scripts/run_pipeline.mjs

# Skip ingest, just process whatever is pending
node scripts/run_pipeline.mjs --enrich-only

# Start fresh: delete existing restaurants and rebuild
node scripts/run_pipeline.mjs --reprocess
```
