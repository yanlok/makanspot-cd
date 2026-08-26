# V2 Scraped Posts & Restaurant Pipeline — Implementation Plan

## Overview

Build a clean, testable v2 version of the scraped post → restaurant pipeline alongside the existing v1 system. The v2 tables use a `v2_` prefix in the same Supabase project. Once validated, v2 becomes canonical and the old tables get cleaned up.

### Key Principles

- v2 tables are completely isolated — no foreign keys to v1 tables
- Same Supabase project — easy to query both for comparison
- Instagram-native schema — no TikTok field remnants
- Normalized but practical — separate tables for sources, images, social metrics
- Full state machine — every post and pipeline run has explicit status transitions
- Cost tracking — scrape runs and discovery sources track USD cost for KPI

---

## 1. Database Schema

### 1.1 `v2_scraped_posts` — staging table for raw Instagram data

```sql
CREATE TABLE v2_scraped_posts (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  platform          TEXT NOT NULL DEFAULT 'instagram',
  external_post_id  TEXT NOT NULL,
  post_url          TEXT,
  author_username   TEXT,
  caption           TEXT,
  hashtags          JSONB DEFAULT '[]',
  location_name     TEXT,
  location_id       TEXT,
  likes             INTEGER DEFAULT 0,
  comments          INTEGER DEFAULT 0,
  views             INTEGER DEFAULT 0,
  media_urls        JSONB DEFAULT '[]',
  cover_url         TEXT,
  posted_at         TIMESTAMPTZ,
  scraped_at        TIMESTAMPTZ DEFAULT now(),
  source_query      TEXT,
  status            TEXT DEFAULT 'pending' CHECK (status IN
                      ('pending','processing','post_detected','candidate_extracted',
                       'resolved','promoted','skipped','failed')),
  error             TEXT,
  created_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE(platform, external_post_id)
);

CREATE INDEX idx_v2_sp_status ON v2_scraped_posts(status);
CREATE INDEX idx_v2_sp_location ON v2_scraped_posts(location_id);
CREATE INDEX idx_v2_sp_author ON v2_scraped_posts(author_username);
```

### 1.2 `v2_restaurants` — canonical restaurant records

```sql
CREATE TABLE v2_restaurants (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name                      TEXT NOT NULL,
  normalized_name           TEXT,
  description               TEXT,
  address                   TEXT,
  city                      TEXT,
  state                     TEXT,
  latitude                  DOUBLE PRECISION,
  longitude                 DOUBLE PRECISION,
  phone                     TEXT,
  website                   TEXT,
  price_range               TEXT,
  instagram_username        TEXT,
  instagram_location_id     TEXT,
  categories                TEXT[] DEFAULT '{}',
  business_hours            JSONB,
  verification_confidence   NUMERIC(3,2) DEFAULT 0,
  is_approved               BOOLEAN DEFAULT false,
  source_post_count         INTEGER DEFAULT 0,
  popularity_score          INTEGER DEFAULT 0,
  last_scraped_at           TIMESTAMPTZ,
  created_at                TIMESTAMPTZ DEFAULT now(),
  updated_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_v2_r_name ON v2_restaurants(normalized_name);
CREATE INDEX idx_v2_r_insta_loc ON v2_restaurants(instagram_location_id);
CREATE INDEX idx_v2_r_insta_user ON v2_restaurants(instagram_username);
CREATE INDEX idx_v2_r_city ON v2_restaurants(city);
CREATE INDEX idx_v2_r_categories ON v2_restaurants USING GIN(categories);
```

### 1.3 `v2_restaurant_sources` — dedup/link table

```sql
CREATE TABLE v2_restaurant_sources (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id   BIGINT NOT NULL REFERENCES v2_restaurants(id) ON DELETE CASCADE,
  platform        TEXT NOT NULL DEFAULT 'instagram',
  source_type     TEXT NOT NULL CHECK (source_type IN ('location_id','profile_id','post_url')),
  external_id     TEXT NOT NULL,
  username        TEXT,
  name            TEXT,
  last_seen_at    TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE(platform, source_type, external_id)
);

CREATE INDEX idx_v2_rs_restaurant ON v2_restaurant_sources(restaurant_id);
```

### 1.4 `v2_restaurant_images` — multiple images per restaurant

```sql
CREATE TABLE v2_restaurant_images (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id   BIGINT NOT NULL REFERENCES v2_restaurants(id) ON DELETE CASCADE,
  source_url      TEXT,
  image_url       TEXT NOT NULL,
  image_type      TEXT DEFAULT 'food' CHECK (image_type IN
                    ('food','storefront','interior','menu','logo','map','other')),
  quality_score   NUMERIC(3,2) DEFAULT 0,
  is_primary      BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_v2_ri_restaurant ON v2_restaurant_images(restaurant_id);
```

### 1.5 `v2_restaurant_social_metrics` — aggregated social data

```sql
CREATE TABLE v2_restaurant_social_metrics (
  restaurant_id         BIGINT PRIMARY KEY REFERENCES v2_restaurants(id) ON DELETE CASCADE,
  mention_count_7d      INTEGER DEFAULT 0,
  mention_count_30d     INTEGER DEFAULT 0,
  mention_count_90d     INTEGER DEFAULT 0,
  unique_creator_count  INTEGER DEFAULT 0,
  total_likes           INTEGER DEFAULT 0,
  total_comments        INTEGER DEFAULT 0,
  total_views           INTEGER DEFAULT 0,
  latest_mention_at     TIMESTAMPTZ,
  trend_score           NUMERIC(5,4) DEFAULT 0,
  updated_at            TIMESTAMPTZ DEFAULT now()
);
```

### 1.6 `v2_restaurant_social_posts` — every IG post linked to a restaurant

```sql
CREATE TABLE v2_restaurant_social_posts (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id   BIGINT NOT NULL REFERENCES v2_restaurants(id) ON DELETE CASCADE,
  post_id         BIGINT NOT NULL REFERENCES v2_scraped_posts(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE(restaurant_id, post_id)
);

CREATE INDEX idx_v2_rsp_restaurant ON v2_restaurant_social_posts(restaurant_id);
CREATE INDEX idx_v2_rsp_post ON v2_restaurant_social_posts(post_id);
```

### 1.7 `v2_discovery_sources` — dynamic source pool

```sql
CREATE TABLE v2_discovery_sources (
  id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_type             TEXT NOT NULL CHECK (source_type IN ('hashtag','account','location','search_query')),
  source_value            TEXT NOT NULL,
  area                    TEXT,
  parent_source_id        BIGINT REFERENCES v2_discovery_sources(id),
  status                  TEXT DEFAULT 'active' CHECK (status IN ('active','paused','saturated','cooldown')),
  scrape_count            INTEGER DEFAULT 0,
  posts_scraped           INTEGER DEFAULT 0,
  new_posts               INTEGER DEFAULT 0,
  restaurant_candidates   INTEGER DEFAULT 0,
  new_restaurants         INTEGER DEFAULT 0,
  verified_restaurants    INTEGER DEFAULT 0,
  total_cost_usd          NUMERIC(10,4) DEFAULT 0,
  yield_rate              NUMERIC(5,4) DEFAULT 0,
  cost_per_new_restaurant NUMERIC(10,4),
  priority_score          NUMERIC(5,4) DEFAULT 0.5,
  last_scraped_at         TIMESTAMPTZ,
  next_scrape_at          TIMESTAMPTZ DEFAULT now(),
  created_at              TIMESTAMPTZ DEFAULT now(),
  UNIQUE(source_type, source_value)
);
```

### 1.8 `v2_scrape_runs` — execution log

```sql
CREATE TABLE v2_scrape_runs (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id             BIGINT REFERENCES v2_discovery_sources(id),
  status                TEXT DEFAULT 'pending' CHECK (status IN ('pending','running','completed','failed')),
  started_at            TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  posts_received        INTEGER DEFAULT 0,
  new_posts             INTEGER DEFAULT 0,
  restaurant_candidates INTEGER DEFAULT 0,
  new_restaurants       INTEGER DEFAULT 0,
  verified_restaurants  INTEGER DEFAULT 0,
  cost_usd              NUMERIC(10,4) DEFAULT 0,
  error                 TEXT,
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_v2_sr_status ON v2_scrape_runs(status);
CREATE INDEX idx_v2_sr_source ON v2_scrape_runs(source_id);
```

### 1.9 RLS Policies

```sql
ALTER TABLE v2_scraped_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_restaurant_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_restaurant_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_restaurant_social_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_restaurant_social_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_discovery_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE v2_scrape_runs ENABLE ROW LEVEL SECURITY;

-- service_role full access (for edge functions)
CREATE POLICY "v2_sp_service_role" ON v2_scraped_posts FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_r_service_role" ON v2_restaurants FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_rs_service_role" ON v2_restaurant_sources FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_ri_service_role" ON v2_restaurant_images FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_rsm_service_role" ON v2_restaurant_social_metrics FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_rsp_service_role" ON v2_restaurant_social_posts FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_ds_service_role" ON v2_discovery_sources FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "v2_sr_service_role" ON v2_scrape_runs FOR ALL USING (auth.role() = 'service_role');

-- Admin read access
CREATE POLICY "v2_sp_admin_read" ON v2_scraped_posts FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_r_admin_read" ON v2_restaurants FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_rs_admin_read" ON v2_restaurant_sources FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_ri_admin_read" ON v2_restaurant_images FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_rsm_admin_read" ON v2_restaurant_social_metrics FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_rsp_admin_read" ON v2_restaurant_social_posts FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_ds_admin_read" ON v2_discovery_sources FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "v2_sr_admin_read" ON v2_scrape_runs FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
```

---

## 2. Edge Functions

### 2.1 `_shared/v2-apify.ts` — field mapping

```typescript
// Instagram-native field mapping (no TikTok fields)
// Maps Apify dataset fields → v2_scraped_posts columns
// Functions: toV2StagingRow(record), mapPlaceResult(result)
```

### 2.2 `_shared/v2-enrich.ts` — processing utilities

```typescript
// Functions:
// - normalizeRestaurantName(name): string
// - isLikelyNotRestaurant(caption, location): boolean
// - extractRestaurantFromCaption(caption, location): Promise<ExtractionResult>
// - calculatePopularityScore(post): number
// - resolveCandidate(candidate, existingSources): Promise<{existing, isNew}>
// - deriveCategories(igCategory, caption): string[]
// - calculateTrendScore(metrics): number
```

### 2.3 `v2-trigger-pipeline/index.ts` — entry point

Responsibilities:
1. Pick exactly one source from `v2_discovery_sources`, ordered by `priority_score DESC`, filtered by `next_scrape_at <= now()` and `status = 'active'`. One source per run keeps cost and yield attribution exact.
2. Start Apify `instagram-search-scraper` run with appropriate query
3. Create `v2_scrape_runs` row
4. Hand off to `v2-pipeline-continue` via `EdgeRuntime.waitUntil`
5. Return `{ job_id, status: 'pending' }`

Input: `{ source_ids?: number[], result_limit?: number }` (only the first explicit source ID is used)
Output: `{ job_id: string, status: string }`

`result_limit` is clamped to `1..20` and defaults to `20`. Use `1` for the
first live verification to minimize Apify usage. Search-query sources create a
`place` dataset; hashtag sources create a `post` dataset, and that mode is
carried in pipeline state so ingestion cannot confuse place records with posts.
Leading `#` characters are stripped before hashtag values are sent to Apify.
Trigger and status calls require a database-backed admin user; continuation is
internal-only and requires the service-role bearer.
Before starting a paid Apify actor, the trigger inserts pending job/run rows.
A partial unique index on active `pipeline_jobs` rows makes the shared lock
race-safe. Initialization failures abort a started actor when possible and mark
both tracking rows failed.

### 2.4 `v2-pipeline-continue/index.ts` — state machine worker

Steps (one per invocation, chains to itself):

| Step | What it does |
|------|-------------|
| `scrape` | Poll Apify run until complete. Record cost_usd. |
| `ingest` | Fetch 10 results from dataset → upsert into `v2_scraped_posts` (dedup by external_post_id). |
| `detect` | For pending posts: keyword filter → mark as `post_detected` or `skipped`. Extract restaurant candidates from detected posts → mark as `candidate_extracted`. |
| `resolve` | For each post candidate, match by Instagram location ID. Never treat the post author (often an influencer) as the restaurant identity. Unmatched rows move once to enrichment. |
| `enrich` | For new candidates: LLM extraction (if needed) → insert into `v2_restaurants` → register sources → set image → mark as `promoted`. |
| `metrics` | Recompute `v2_restaurant_social_metrics`, source-post counts, and MAX-based popularity for affected restaurants. |
| `complete` | Update discovery-source yield/cooldown and scrape-run totals, then mark the run and job completed. |

Each step updates `pipeline_jobs.result` JSONB with current progress, then chains to itself for the next step.

Place ingestion creates or updates canonical restaurants from Instagram place
metadata, registers `location_id` sources, requires positive food evidence from
the place name/category or embedded posts, and captures embedded posts. Unknown
place metadata alone never creates a canonical restaurant. Explicit hotel,
mall, park, and other non-food metadata always blocks canonicalization, though
embedded posts are still staged for independent restaurant extraction. Post processing is scoped to IDs newly inserted by
the current run. Replaying a dataset therefore leaves terminal post statuses
unchanged and reports `new_posts = 0`.

Post candidates deduplicate by location ID first, then by normalized name plus
nearby coordinates. When geocoding is unavailable, matching requires exact name
plus city, or a name relationship backed by matching address evidence. Linked
posts register `post_url` sources; creator usernames are never restaurant
identities.

### Automatic pictures and paid-run components

Embedded place posts are normalized first, including Instagram's nested
`code`, caption, `image_versions2`, engagement, timestamp, user, location, and
`parentData` shapes. Their exact location ID is inherited from the place when
needed. If an eligible restaurant still has neither a primary image nor an
embedded cover, the pipeline queues its exact Instagram location URL. It starts
at most one follow-up `apify/instagram-scraper` component with
`resultsType="posts"`, `resultsLimit=3`, and `addParentData=true`; it never does
a broad name search. The follow-up is globally bounded to one exact location
URL and three dataset items total, regardless of unexpected actor output.

Every paid actor is recorded in `v2_scrape_run_components` before it starts.
Discovery and optional `location_posts` components store their actor/run/dataset
IDs, lifecycle, item count, and settled cost. Run cost is the sum of component
costs; legacy runs without components retain the previous single-run fallback.

After all posts are linked, metrics deterministically rank existing cover URLs
using engagement, recency, and food-caption evidence, with penalties for ads,
logos, menus, giveaways, hiring, and announcements. Only the winning URL is
downloaded/rehosted. It replaces the primary only when no primary exists or its
quality score is strictly higher. This applies to existing matched restaurants
as well as new ones.

Place metadata missing address or city uses one Mapbox Geocoding v6 reverse
request when coordinates exist. Stored results use `country=my` and
`permanent=true`; supplied fields are never overwritten. Posts resolved by an
exact location ID never reverse-geocode.

### 2.5 `v2-pipeline-status/index.ts` — status endpoint

Queries `v2_scrape_runs` and `v2_scraped_posts` for current status. Returns:
```json
{
  "job_id": "...",
  "status": "running",
  "current_step": "enrich",
  "posts_received": 85,
  "new_posts": 72,
  "restaurant_candidates": 23,
  "new_restaurants": 8,
  "cost_usd": 0.12
}
```

---

## 3. Flutter Admin UI

### 3.1 New files

```
lib/features/admin/
  controllers/
    v2_data_scraper_controller.dart
  models/
    v2_admin_models.dart
  views/
    v2_data_scraper_screen.dart
```

### 3.2 `v2_admin_models.dart`

```dart
class V2ScanResult {
  final int postsReceived;
  final int newPosts;
  final int restaurantCandidates;
  final int newRestaurants;
  final int verifiedRestaurants;
  final double costUsd;
}

class V2PipelineState {
  final V2PipelineStatus status;
  final V2PipelineStep? currentStep;
  final String? stepMessage;
  final V2ScanResult? result;
  final DateTime? lastScanTime;
  final String? error;
  final String? activeJobId;
}

enum V2PipelineStatus { idle, scanning, processing, complete, error }
enum V2PipelineStep { scrape, ingest, detect, resolve, enrich, metrics }
```

### 3.3 `v2_data_scraper_controller.dart`

Mirrors `DataScraperController` but targets v2 edge functions:
- `triggerV2Pipeline()` → invokes `v2-trigger-pipeline`
- `pollV2Status()` → queries `v2_scrape_runs` and `v2_scraped_posts` status counts
- `loadV2Stats()` → reads aggregate stats from v2 tables
- Polls every 5 seconds while running

### 3.4 `v2_data_scraper_screen.dart`

Admin screen showing:
- **Trigger button** — starts v2 pipeline
- **Live status** — current step, progress message
- **Results card** — posts received, new posts, candidates, new restaurants, cost
- **Cost per restaurant** — the key KPI, highlighted
- **Discovery sources table** — source, yield, cost, last scraped, status
- **Recent scrape runs** — history with status and stats

### 3.5 Router update

Add route in `app_router.dart`:
```dart
GoRoute(
  path: 'v2-scrape',
  name: 'v2-scrape',
  builder: (context, state) => const V2DataScraperScreen(),
),
```

Add to `AdminShell` navigation items.

---

## 4. Post Status State Machine

```
pending → processing → post_detected → candidate_extracted → resolved → promoted
    ↓           ↓              ↓                ↓               ↓
  skipped     failed         skipped          skipped         failed
```

Each transition is explicit and logged. Failed posts can be retried by resetting status to `pending`.

---

## 5. Discovery Source Priority Score

```
Priority Score =
    0.40 × Normalized Yield
  + 0.30 × Cost Efficiency (inverted: lower cost = higher score)
  + 0.20 × Source Freshness (days since last scrape, capped)
  + 0.10 × Exploration Bonus (new sources get a boost)
```

### Cooldown Rules

| Yield | Cooldown |
|-------|----------|
| High (>20%) | 1–2 days |
| Medium (5–20%) | 3–7 days |
| Low (1–5%) | 7–14 days |
| Very low (<1%) | Pause |

---

## 6. Popularity Score V2

```
popularity_score =
  (likes × 1.0) +
  (comments × 2.0) +
  (views × 0.01) +
  (log10(creator_followers + 1) × 5.0) [if available]
```

Use MAX-based merge when multiple posts reference the same restaurant (not additive).

---

## 7. Trend Score V2

```
Trend Score =
    0.35 × Mention Velocity (posts in last 7d / posts in previous 7d)
  + 0.25 × Creator Diversity (unique creators / total mentions)
  + 0.20 × Normalized Engagement (avg likes+comments per post, normalized)
  + 0.20 × Recency (1.0 if mentioned today, decays over 30 days)
```

---

## 8. Implementation Order

| # | Task | Files to Create/Modify |
|---|------|----------------------|
| 1 | Create v2 migration | `supabase/migrations/20260819000100_v2_schema.sql` |
| 2 | Write v2 shared modules | `supabase/functions/_shared/v2-apify.ts` |
| | | `supabase/functions/_shared/v2-enrich.ts` |
| 3 | Build v2 trigger function | `supabase/functions/v2-trigger-pipeline/index.ts` |
| 4 | Build v2 pipeline-continue | `supabase/functions/v2-pipeline-continue/index.ts` |
| 5 | Build v2 pipeline-status | `supabase/functions/v2-pipeline-status/index.ts` |
| 6 | Flutter v2 models | `lib/features/admin/models/v2_admin_models.dart` |
| 7 | Flutter v2 controller | `lib/features/admin/controllers/v2_data_scraper_controller.dart` |
| 8 | Flutter v2 admin screen | `lib/features/admin/views/v2_data_scraper_screen.dart` |
| 9 | Router update | `lib/core/router/app_router.dart` |
| 10 | Test end-to-end | Run v2 pipeline, verify data in v2 tables |
| 11 | Code review | Delegate to code-reviewer |

---

## 9. Testing Checklist

Run pure mapping/filter/scoring tests locally before any paid smoke test:

```bash
cd supabase/functions
deno test _shared/v2_pipeline_test.ts
deno fmt --check _shared/v2-apify.ts _shared/v2-enrich.ts \
  _shared/v2_pipeline_test.ts v2-trigger-pipeline/index.ts \
  v2-pipeline-continue/index.ts
```

For the first deployed smoke test, choose one `search_query` source and send
`{"source_ids":[ID],"result_limit":1}`. Expect exactly one discovery result.
If it has no embedded cover/primary image, expect at most one follow-up location
target and at most three posts from the exact Instagram location URL. Verify one
canonical restaurant, one `location_id` source, linked posts, one deterministic
primary image, two component rows at most, and run cost equal to component-cost
sum. If an embedded cover exists, expect only the discovery component.

Replay the same fixture/source after intentionally overriding cooldown. It must
create no duplicate restaurant or image, preserve terminal posts, and report
zero newly inserted posts when actor results are identical. No public fixture
API is provided. For a no-paid local replay, save representative discovery and
location-post JSON fixtures and exercise `toV2PlaceCandidate`,
`v2PlacePostsToRows`, `toV2StagingRow`, image ranking, queue suppression, and
component-cost helpers with `deno test`; database idempotency is then verified
against a local Supabase stack using the same fixtures.

- [ ] Migration runs cleanly on fresh Supabase
- [ ] Seed discovery sources appear in `v2_discovery_sources`
- [ ] `v2-trigger-pipeline` starts an Apify run and creates a `v2_scrape_runs` row
- [ ] Posts appear in `v2_scraped_posts` with correct `external_post_id` dedup
- [ ] Restaurant candidates are extracted from food posts
- [ ] Existing restaurants are matched via `v2_restaurant_sources`
- [ ] New restaurants are created in `v2_restaurants` with `is_approved=false`
- [ ] Images are stored in `v2_restaurant_images`
- [ ] Social metrics are calculated in `v2_restaurant_social_metrics`
- [ ] Discovery source yield and cooldown are updated
- [ ] Cost per new restaurant KPI is calculated correctly
- [ ] Admin UI shows live pipeline status
- [ ] Failed posts can be retried (status reset to pending)
- [ ] Duplicate posts are rejected (UNIQUE constraint on external_post_id)
- [ ] v2 tables are completely independent of v1 tables

---

## 10. Migration Strategy (Future, Not In This Task)

Once v2 is validated:

1. Rename v2 tables to drop the `v2_` prefix
2. Drop old v1 tables (`scraped_posts`, `restaurants`, `restaurant_sources`, etc.)
3. Update all Flutter model references
4. Remove v1 edge functions (`trigger-pipeline`, `pipeline-continue`, etc.)
5. Remove v1 admin UI (`data_scraper_screen.dart`, `data_scraper_controller.dart`)
6. Clean up old docs

---

## 11. File Tree Summary

```
supabase/
  migrations/
    20260819000100_v2_schema.sql          ← NEW
  functions/
    _shared/
      v2-apify.ts                          ← NEW
      v2-enrich.ts                         ← NEW
    v2-trigger-pipeline/
      index.ts                             ← NEW
    v2-pipeline-continue/
      index.ts                             ← NEW
    v2-pipeline-status/
      index.ts                             ← NEW

lib/features/admin/
  controllers/
    v2_data_scraper_controller.dart        ← NEW
  models/
    v2_admin_models.dart                   ← NEW
  views/
    v2_data_scraper_screen.dart            ← NEW

lib/core/router/
  app_router.dart                          ← MODIFY (add v2-scrape route)

docs/
  v2-pipeline-implementation.md            ← THIS FILE
```
