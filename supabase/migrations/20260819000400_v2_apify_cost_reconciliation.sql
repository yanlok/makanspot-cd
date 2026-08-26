ALTER TABLE public.v2_scrape_runs
  ADD COLUMN IF NOT EXISTS apify_run_id text,
  ADD COLUMN IF NOT EXISTS dataset_id text;

CREATE INDEX IF NOT EXISTS idx_v2_sr_apify_run
  ON public.v2_scrape_runs (apify_run_id);

-- Reconcile the one-result production smoke test after Apify finalized its
-- pay-per-result charge. Future runs refresh settled usage before completion.
WITH reconciled_run AS (
  UPDATE public.v2_scrape_runs
  SET apify_run_id = 'aOegaliQ1YLBWYMrO',
      dataset_id = 'jABrOjMHIRJUAYcmD',
      cost_usd = 0.0027
  WHERE id = '1244d7c6-a56c-4174-9a1a-eeb0b32b4a2d'
    AND source_id = 7
  RETURNING source_id
)
UPDATE public.v2_discovery_sources
SET posts_scraped = 1,
    total_cost_usd = 0.0027,
    yield_rate = 1,
    cost_per_new_restaurant = 0.0027
WHERE id IN (SELECT source_id FROM reconciled_run)
  AND scrape_count = 1
  AND new_restaurants = 1;
