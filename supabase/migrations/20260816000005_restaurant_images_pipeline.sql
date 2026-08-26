-- Restaurant photos from the pipeline (100% free tier strategy):
--   Tier 1: social post cover images (scraped_posts.cover_url / IG displayUrl)
--   Tier 2: IG business profile pic (ig_business.profile.profile_pic_url)
--   Tier 3: Mapbox Static Images map card (50K free req/month, same free account)
-- The pipeline (service_role) now writes into restaurant_images, which the app
-- already reads as the restaurant's visual (primary image).

-- Same root cause as 20260816000003/000004: tables created via CLI migrations
-- do not inherit Supabase's default privileges, so the Edge Functions
-- (service_role) hit "permission denied" when writing restaurant_images.
GRANT ALL ON TABLE public.restaurant_images TO service_role;
-- Speed up per-restaurant image lookups (primary demotion + dedup checks).
CREATE INDEX IF NOT EXISTS idx_restaurant_images_restaurant
  ON public.restaurant_images(restaurant_id);
