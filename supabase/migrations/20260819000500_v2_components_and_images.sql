CREATE TABLE IF NOT EXISTS public.v2_scrape_run_components (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scrape_run_id uuid NOT NULL REFERENCES public.v2_scrape_runs(id) ON DELETE CASCADE,
  component_type text NOT NULL CHECK (component_type IN ('discovery', 'location_posts')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  actor_id text NOT NULL,
  apify_run_id text,
  dataset_id text,
  item_count integer NOT NULL DEFAULT 0,
  cost_usd numeric(10,4) NOT NULL DEFAULT 0,
  error text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scrape_run_id, component_type)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_v2_src_apify_run
  ON public.v2_scrape_run_components(apify_run_id)
  WHERE apify_run_id IS NOT NULL;

ALTER TABLE public.v2_scrape_run_components ENABLE ROW LEVEL SECURITY;
CREATE POLICY "v2_src_service_role" ON public.v2_scrape_run_components
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "v2_src_admin_read" ON public.v2_scrape_run_components
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );
GRANT ALL ON public.v2_scrape_run_components TO service_role;
GRANT SELECT ON public.v2_scrape_run_components TO authenticated;

-- Backfill the exact guarded smoke trace without changing its reconciliation.
INSERT INTO public.v2_scrape_run_components (
  scrape_run_id, component_type, status, actor_id, apify_run_id, dataset_id,
  item_count, cost_usd, started_at, completed_at
)
SELECT id, 'discovery', 'completed', 'apify/instagram-search-scraper',
       apify_run_id, dataset_id, posts_received, cost_usd, started_at, completed_at
FROM public.v2_scrape_runs
WHERE apify_run_id IS NOT NULL
ON CONFLICT (scrape_run_id, component_type) DO NOTHING;

-- Keep the highest-quality duplicate and at most one existing primary.
WITH ranked AS (
  SELECT id, row_number() OVER (
    PARTITION BY restaurant_id, image_url
    ORDER BY quality_score DESC NULLS LAST, is_primary DESC, id
  ) AS rn
  FROM public.v2_restaurant_images
)
DELETE FROM public.v2_restaurant_images i USING ranked r
WHERE i.id = r.id AND r.rn > 1;

WITH ranked AS (
  SELECT id, row_number() OVER (
    PARTITION BY restaurant_id
    ORDER BY quality_score DESC NULLS LAST, id
  ) AS rn
  FROM public.v2_restaurant_images
  WHERE is_primary
)
UPDATE public.v2_restaurant_images i SET is_primary = false
FROM ranked r WHERE i.id = r.id AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_v2_ri_restaurant_image_unique
  ON public.v2_restaurant_images(restaurant_id, image_url);
CREATE UNIQUE INDEX IF NOT EXISTS idx_v2_ri_one_primary
  ON public.v2_restaurant_images(restaurant_id) WHERE is_primary;
