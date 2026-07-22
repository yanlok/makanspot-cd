-- Fix ON CONFLICT support for restaurant dedup.
-- The previous partial unique index (WHERE post_url IS NOT NULL) cannot be used
-- for `ON CONFLICT (post_url)` inference, which broke the enrichment upsert with
-- "there is no unique or exclusion constraint matching the ON CONFLICT
-- specification". A plain unique index still allows multiple NULL post_url
-- values (Postgres treats NULLs as distinct), so manually-added restaurants are
-- unaffected, while ON CONFLICT inference now works.

DROP INDEX IF EXISTS idx_restaurants_post_url;
CREATE UNIQUE INDEX IF NOT EXISTS idx_restaurants_post_url
    ON public.restaurants (post_url);
