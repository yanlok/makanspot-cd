-- V2 to Main Migration
-- Promotes v2 tables to become the primary restaurant system.
-- Renames v2_* tables, drops obsolete v1 tables, and cleans up indexes/policies.

-- ============================================================
-- 1. Drop v1 tables (order matters due to FK constraints)
-- ============================================================

-- First, drop FK constraints that reference the v1 restaurants table
-- so we can drop restaurants without CASCADE (preserving dependent tables)
ALTER TABLE IF EXISTS public.reviews DROP CONSTRAINT IF EXISTS reviews_restaurant_id_fkey;
ALTER TABLE IF EXISTS public.bookmarks DROP CONSTRAINT IF EXISTS bookmarks_restaurant_id_fkey;
ALTER TABLE IF EXISTS public.posts DROP CONSTRAINT IF EXISTS posts_restaurant_id_fkey;
ALTER TABLE IF EXISTS public.restaurant_sources DROP CONSTRAINT IF EXISTS restaurant_sources_restaurant_id_fkey;

-- Now drop tables in order (no FK dependencies on restaurants remain)
DROP TABLE IF EXISTS public.scraped_posts;
DROP TABLE IF EXISTS public.restaurant_images;
DROP TABLE IF EXISTS public.restaurant_categories;
DROP TABLE IF EXISTS public.restaurant_menu;
DROP TABLE IF EXISTS public.restaurant_sources;
DROP TABLE IF EXISTS public.discovery_queries;
DROP TABLE IF EXISTS public.restaurants;
DROP TABLE IF EXISTS public.pipeline_jobs;

-- ============================================================
-- 2. Rename v2 tables (drop v2_ prefix)
-- ============================================================
ALTER TABLE IF EXISTS public.v2_scraped_posts RENAME TO scraped_posts;
ALTER TABLE IF EXISTS public.v2_restaurants RENAME TO restaurants;
ALTER TABLE IF EXISTS public.v2_restaurant_sources RENAME TO restaurant_sources;
ALTER TABLE IF EXISTS public.v2_restaurant_images RENAME TO restaurant_images;
ALTER TABLE IF EXISTS public.v2_restaurant_social_metrics RENAME TO restaurant_social_metrics;
ALTER TABLE IF EXISTS public.v2_restaurant_social_posts RENAME TO restaurant_social_posts;
ALTER TABLE IF EXISTS public.v2_discovery_sources RENAME TO discovery_sources;
ALTER TABLE IF EXISTS public.v2_scrape_runs RENAME TO scrape_runs;
ALTER TABLE IF EXISTS public.v2_scrape_run_components RENAME TO scrape_run_components;

-- Add result column to scrape_runs for pipeline state storage (replaces pipeline_jobs.result)
ALTER TABLE public.scrape_runs ADD COLUMN IF NOT EXISTS result JSONB;

-- ============================================================
-- 3. Rename indexes
-- ============================================================
ALTER INDEX IF EXISTS idx_v2_sp_status RENAME TO idx_sp_status;
ALTER INDEX IF EXISTS idx_v2_sp_location RENAME TO idx_sp_location;
ALTER INDEX IF EXISTS idx_v2_sp_author RENAME TO idx_sp_author;
ALTER INDEX IF EXISTS idx_v2_r_name RENAME TO idx_r_name;
ALTER INDEX IF EXISTS idx_v2_r_insta_loc RENAME TO idx_r_insta_loc;
ALTER INDEX IF EXISTS idx_v2_r_insta_user RENAME TO idx_r_insta_user;
ALTER INDEX IF EXISTS idx_v2_r_city RENAME TO idx_r_city;
ALTER INDEX IF EXISTS idx_v2_r_categories RENAME TO idx_r_categories;
ALTER INDEX IF EXISTS idx_v2_rs_restaurant RENAME TO idx_rs_restaurant;
ALTER INDEX IF EXISTS idx_v2_ri_restaurant RENAME TO idx_ri_restaurant;
ALTER INDEX IF EXISTS idx_v2_rsp_restaurant RENAME TO idx_rsp_restaurant;
ALTER INDEX IF EXISTS idx_v2_rsp_post RENAME TO idx_rsp_post;
ALTER INDEX IF EXISTS idx_v2_sr_status RENAME TO idx_sr_status;
ALTER INDEX IF EXISTS idx_v2_sr_source RENAME TO idx_sr_source;
ALTER INDEX IF EXISTS idx_v2_sr_apify_run RENAME TO idx_sr_apify_run;
ALTER INDEX IF EXISTS idx_v2_src_apify_run RENAME TO idx_src_apify_run;

-- Unique indexes from components migration
ALTER INDEX IF EXISTS idx_v2_ri_restaurant_image_unique RENAME TO idx_ri_restaurant_image_unique;
ALTER INDEX IF EXISTS idx_v2_ri_one_primary RENAME TO idx_ri_one_primary;

-- ============================================================
-- 4. Rename RLS policies
-- ============================================================

-- scraped_posts
ALTER POLICY IF EXISTS "v2_sp_service_role" ON public.scraped_posts RENAME TO "sp_service_role";
ALTER POLICY IF EXISTS "v2_sp_admin_read" ON public.scraped_posts RENAME TO "sp_admin_read";

-- restaurants
ALTER POLICY IF EXISTS "v2_r_service_role" ON public.restaurants RENAME TO "r_service_role";
ALTER POLICY IF EXISTS "v2_r_admin_read" ON public.restaurants RENAME TO "r_admin_read";

-- restaurant_sources
ALTER POLICY IF EXISTS "v2_rs_service_role" ON public.restaurant_sources RENAME TO "rs_service_role";
ALTER POLICY IF EXISTS "v2_rs_admin_read" ON public.restaurant_sources RENAME TO "rs_admin_read";

-- restaurant_images
ALTER POLICY IF EXISTS "v2_ri_service_role" ON public.restaurant_images RENAME TO "ri_service_role";
ALTER POLICY IF EXISTS "v2_ri_admin_read" ON public.restaurant_images RENAME TO "ri_admin_read";

-- restaurant_social_metrics
ALTER POLICY IF EXISTS "v2_rsm_service_role" ON public.restaurant_social_metrics RENAME TO "rsm_service_role";
ALTER POLICY IF EXISTS "v2_rsm_admin_read" ON public.restaurant_social_metrics RENAME TO "rsm_admin_read";

-- restaurant_social_posts
ALTER POLICY IF EXISTS "v2_rsp_service_role" ON public.restaurant_social_posts RENAME TO "rsp_service_role";
ALTER POLICY IF EXISTS "v2_rsp_admin_read" ON public.restaurant_social_posts RENAME TO "rsp_admin_read";

-- discovery_sources
ALTER POLICY IF EXISTS "v2_ds_service_role" ON public.discovery_sources RENAME TO "ds_service_role";
ALTER POLICY IF EXISTS "v2_ds_admin_read" ON public.discovery_sources RENAME TO "ds_admin_read";

-- scrape_runs
ALTER POLICY IF EXISTS "v2_sr_service_role" ON public.scrape_runs RENAME TO "sr_service_role";
ALTER POLICY IF EXISTS "v2_sr_admin_read" ON public.scrape_runs RENAME TO "sr_admin_read";

-- scrape_run_components
ALTER POLICY IF EXISTS "v2_src_service_role" ON public.scrape_run_components RENAME TO "src_service_role";
ALTER POLICY IF EXISTS "v2_src_admin_read" ON public.scrape_run_components RENAME TO "src_admin_read";

-- ============================================================
-- 5. Recreate admin read policies with correct table references
--    (policies reference table names in USING clause, so we
--     need to ensure they work with the new table names)
-- ============================================================

-- Drop and recreate admin read policies to ensure correct references
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'scraped_posts', 'restaurants', 'restaurant_sources',
        'restaurant_images', 'restaurant_social_metrics',
        'restaurant_social_posts', 'discovery_sources',
        'scrape_runs', 'scrape_run_components'
      )
      AND policyname LIKE '%admin_read'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',
      policy_record.policyname, policy_record.tablename);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING '
      || '(EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = ''admin''))',
      policy_record.policyname,
      policy_record.tablename
    );
  END LOOP;
END $$;

-- ============================================================
-- 6. Update GRANT statements for renamed tables
-- ============================================================
GRANT ALL ON TABLE
  public.scraped_posts,
  public.restaurants,
  public.restaurant_sources,
  public.restaurant_images,
  public.restaurant_social_metrics,
  public.restaurant_social_posts,
  public.discovery_sources,
  public.scrape_runs,
  public.scrape_run_components
TO service_role;

GRANT SELECT ON TABLE
  public.scraped_posts,
  public.restaurants,
  public.restaurant_sources,
  public.restaurant_images,
  public.restaurant_social_metrics,
  public.restaurant_social_posts,
  public.discovery_sources,
  public.scrape_runs,
  public.scrape_run_components
TO authenticated;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================
-- 7. Re-add FK constraints for community tables pointing to new restaurants
-- ============================================================
ALTER TABLE IF EXISTS public.reviews
  ADD CONSTRAINT reviews_restaurant_id_fkey
  FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id);

ALTER TABLE IF EXISTS public.bookmarks
  ADD CONSTRAINT bookmarks_restaurant_id_fkey
  FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id);

ALTER TABLE IF EXISTS public.posts
  ADD CONSTRAINT posts_restaurant_id_fkey
  FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id);
