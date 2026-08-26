-- Follow-up hardening for deployments where 20260819000100 is already applied.

-- The trigger uses pipeline_jobs as the shared v1/v2 lock. A constant-key
-- partial unique index closes the race between checking and inserting.
CREATE UNIQUE INDEX IF NOT EXISTS idx_pipeline_jobs_one_active
ON public.pipeline_jobs ((true))
WHERE status IN ('pending', 'running');

GRANT ALL ON TABLE
  public.v2_scraped_posts,
  public.v2_restaurants,
  public.v2_restaurant_sources,
  public.v2_restaurant_images,
  public.v2_restaurant_social_metrics,
  public.v2_restaurant_social_posts,
  public.v2_discovery_sources,
  public.v2_scrape_runs
TO service_role;

GRANT SELECT ON TABLE
  public.v2_scraped_posts,
  public.v2_restaurants,
  public.v2_restaurant_sources,
  public.v2_restaurant_images,
  public.v2_restaurant_social_metrics,
  public.v2_restaurant_social_posts,
  public.v2_discovery_sources,
  public.v2_scrape_runs
TO authenticated;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

DO $$
DECLARE
  table_name text;
  policy_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'v2_scraped_posts', 'v2_restaurants', 'v2_restaurant_sources',
    'v2_restaurant_images', 'v2_restaurant_social_metrics',
    'v2_restaurant_social_posts', 'v2_discovery_sources', 'v2_scrape_runs'
  ]
  LOOP
    policy_name := CASE table_name
      WHEN 'v2_scraped_posts' THEN 'v2_sp_admin_read'
      WHEN 'v2_restaurants' THEN 'v2_r_admin_read'
      WHEN 'v2_restaurant_sources' THEN 'v2_rs_admin_read'
      WHEN 'v2_restaurant_images' THEN 'v2_ri_admin_read'
      WHEN 'v2_restaurant_social_metrics' THEN 'v2_rsm_admin_read'
      WHEN 'v2_restaurant_social_posts' THEN 'v2_rsp_admin_read'
      WHEN 'v2_discovery_sources' THEN 'v2_ds_admin_read'
      WHEN 'v2_scrape_runs' THEN 'v2_sr_admin_read'
    END;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', policy_name, table_name);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING '
      || '(EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = ''admin''))',
      policy_name,
      table_name
    );
  END LOOP;
END $$;

INSERT INTO public.v2_discovery_sources (source_type, source_value, area)
VALUES ('hashtag', '#ttdifood', 'Taman Tun Dr Ismail')
ON CONFLICT (source_type, source_value) DO UPDATE
SET area = EXCLUDED.area;

DELETE FROM public.v2_discovery_sources
WHERE source_type = 'hashtag' AND source_value = '#ttfifood';
