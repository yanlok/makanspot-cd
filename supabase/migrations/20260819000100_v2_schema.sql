-- V2 Schema: Clean scraped posts & restaurant pipeline
-- This migration is completely independent of v1 tables.

-- ============================================================
-- 1. v2_scraped_posts — staging table for raw Instagram data
-- ============================================================
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
-- ============================================================
-- 2. v2_restaurants — canonical restaurant records
-- ============================================================
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
-- ============================================================
-- 3. v2_restaurant_sources — dedup/link table
-- ============================================================
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
-- ============================================================
-- 4. v2_restaurant_images — multiple images per restaurant
-- ============================================================
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
-- ============================================================
-- 5. v2_restaurant_social_metrics — aggregated social data
-- ============================================================
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
-- ============================================================
-- 6. v2_restaurant_social_posts — every IG post linked to a restaurant
-- ============================================================
CREATE TABLE v2_restaurant_social_posts (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id   BIGINT NOT NULL REFERENCES v2_restaurants(id) ON DELETE CASCADE,
  post_id         BIGINT NOT NULL REFERENCES v2_scraped_posts(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE(restaurant_id, post_id)
);
CREATE INDEX idx_v2_rsp_restaurant ON v2_restaurant_social_posts(restaurant_id);
CREATE INDEX idx_v2_rsp_post ON v2_restaurant_social_posts(post_id);
-- ============================================================
-- 7. v2_discovery_sources — dynamic source pool
-- ============================================================
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
-- ============================================================
-- 8. v2_scrape_runs — execution log
-- ============================================================
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
-- ============================================================
-- 9. RLS Policies
-- ============================================================
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
-- ============================================================
-- 10. Seed data — initial discovery sources for KL/PJ/Subang
-- ============================================================
INSERT INTO v2_discovery_sources (source_type, source_value, area) VALUES
  ('search_query', 'PJ food', 'Petaling Jaya'),
  ('search_query', 'KL food', 'Kuala Lumpur'),
  ('search_query', 'Subang food', 'Subang Jaya'),
  ('hashtag', '#pjfood', 'Petaling Jaya'),
  ('hashtag', '#klfood', 'Kuala Lumpur'),
  ('hashtag', '#subangfood', 'Subang Jaya'),
  ('search_query', 'SS15 cafe', 'Subang Jaya'),
  ('search_query', 'Kepong cafe', 'Kepong'),
  ('search_query', 'Bangsar food', 'Bangsar'),
  ('search_query', 'TTDI food', 'Taman Tun Dr Ismail'),
  ('hashtag', '#ss15dessert', 'Subang Jaya'),
  ('hashtag', '#subangcafe', 'Subang Jaya'),
  ('hashtag', '#kepongfood', 'Kepong'),
  ('hashtag', '#bangsarfood', 'Bangsar'),
  ('hashtag', '#ttfifood', 'Taman Tun Dr Ismail');
