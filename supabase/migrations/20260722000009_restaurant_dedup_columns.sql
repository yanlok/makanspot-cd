-- Dedup / aggregation columns for the enrichment pipeline.
-- Multiple scraped videos can reference the same real-world restaurant. Instead
-- of inserting a duplicate row per video, the enrich function now merges them
-- into one restaurant and aggregates engagement here:
--   source_post_count -> how many scraped videos mention this restaurant
--   top_play_count    -> play count of the current "best" (primary) video, used
--                        to decide which post_url / cover image wins.

ALTER TABLE public.restaurants
    ADD COLUMN IF NOT EXISTS source_post_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS top_play_count INTEGER DEFAULT 0;
