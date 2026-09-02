-- Discovery optimization: platform source-level dedup, place-first discovery,
-- and a discovery query registry with yield/cooldown tracking.
--
-- restaurant_sources  — maps an IG location_id / owner profile to the
--                       canonical restaurant row so posts from known sources
--                       can skip LLM extraction + geocoding entirely.
-- discovery_queries   — registry of place/hashtag discovery queries with
--                       yield / cooldown / saturation tracking so the
--                       scheduler stops paying for saturated sources.

-- Table 1: restaurant_sources
CREATE TABLE IF NOT EXISTS public.restaurant_sources (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id BIGINT NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,            -- 'instagram' | 'tiktok'
  source_type TEXT NOT NULL,         -- 'place' | 'profile'
  external_id TEXT NOT NULL,         -- IG location_id or owner_id (fallback: username)
  username TEXT,                     -- ownerUsername / place slug
  url TEXT,
  name TEXT,                         -- locationName / display name (debugging)
  last_seen_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT restaurant_sources_uniq UNIQUE (platform, source_type, external_id)
);
CREATE INDEX IF NOT EXISTS idx_restaurant_sources_restaurant ON public.restaurant_sources(restaurant_id);
ALTER TABLE public.restaurant_sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role can manage restaurant sources" ON public.restaurant_sources
  FOR ALL USING (true) WITH CHECK (true);
-- Grant service_role full access. Same root cause as 20260816000003: tables
-- created via CLI migrations do not inherit Supabase default privileges.
GRANT ALL ON TABLE public.restaurant_sources TO service_role;
-- Table 2: discovery_queries
CREATE TABLE IF NOT EXISTS public.discovery_queries (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  platform TEXT NOT NULL DEFAULT 'instagram',
  query_type TEXT NOT NULL DEFAULT 'place' CHECK (query_type IN ('place', 'hashtag')),
  query TEXT NOT NULL,
  location TEXT,
  category TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'saturated')),
  scrape_count INTEGER DEFAULT 0,
  zero_runs INTEGER DEFAULT 0,
  last_scraped_at TIMESTAMPTZ,
  last_result_count INTEGER,
  last_new_places INTEGER,
  duplicate_rate NUMERIC(5,4),
  discovery_yield NUMERIC(5,4),
  next_scrape_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT discovery_queries_uniq UNIQUE (platform, query_type, query)
);
ALTER TABLE public.discovery_queries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role can manage discovery queries" ON public.discovery_queries
  FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.discovery_queries TO service_role;
-- Staging columns: capture IG identity on ingest so the enrich fast-path can
-- resolve known sources without LLM/geocode.
ALTER TABLE public.scraped_posts
  ADD COLUMN IF NOT EXISTS location_id TEXT,
  ADD COLUMN IF NOT EXISTS location_name TEXT,
  ADD COLUMN IF NOT EXISTS owner_id TEXT;
CREATE INDEX IF NOT EXISTS idx_scraped_posts_location ON public.scraped_posts(location_id);
-- Seed place discovery queries (location x category grid, Kuala Lumpur +
-- Penang hotspots). ON CONFLICT DO NOTHING keeps operator tweaks intact.
INSERT INTO public.discovery_queries (platform, query_type, query, location, category) VALUES
  ('instagram', 'place', 'ss15 cafe', 'SS15', 'cafe'),
  ('instagram', 'place', 'ss15 dessert', 'SS15', 'dessert'),
  ('instagram', 'place', 'ss2 cafe', 'SS2', 'cafe'),
  ('instagram', 'place', 'ss2 local food', 'SS2', 'local food'),
  ('instagram', 'place', 'damansara cafe', 'Damansara', 'cafe'),
  ('instagram', 'place', 'damansara japanese', 'Damansara', 'japanese'),
  ('instagram', 'place', 'kelana jaya cafe', 'Kelana Jaya', 'cafe'),
  ('instagram', 'place', 'kelana jaya dessert', 'Kelana Jaya', 'dessert'),
  ('instagram', 'place', 'cheras chinese food', 'Cheras', 'chinese food'),
  ('instagram', 'place', 'cheras hidden gem', 'Cheras', 'hidden gem'),
  ('instagram', 'place', 'kepong local food', 'Kepong', 'local food'),
  ('instagram', 'place', 'kepong seafood', 'Kepong', 'seafood'),
  ('instagram', 'place', 'sri petaling cafe', 'Sri Petaling', 'cafe'),
  ('instagram', 'place', 'sri petaling korean', 'Sri Petaling', 'korean'),
  ('instagram', 'place', 'puchong chinese food', 'Puchong', 'chinese food'),
  ('instagram', 'place', 'puchong cafe', 'Puchong', 'cafe'),
  ('instagram', 'place', 'bukit bintang cafe', 'Bukit Bintang', 'cafe'),
  ('instagram', 'place', 'bukit bintang japanese', 'Bukit Bintang', 'japanese'),
  ('instagram', 'place', 'bangsar cafe', 'Bangsar', 'cafe'),
  ('instagram', 'place', 'bangsar dessert', 'Bangsar', 'dessert'),
  ('instagram', 'place', 'george town local food', 'George Town', 'local food'),
  ('instagram', 'place', 'george town cafe', 'George Town', 'cafe'),
  ('instagram', 'place', 'air itam malay food', 'Air Itam', 'malay food'),
  ('instagram', 'place', 'air itam nasi lemak', 'Air Itam', 'nasi lemak')
ON CONFLICT (platform, query_type, query) DO NOTHING;
