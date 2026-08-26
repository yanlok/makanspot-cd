-- Restaurants are customer-facing records. The approval workflow is no longer
-- part of the product, so expose restaurant data to app clients and remove the
-- obsolete flag.
GRANT SELECT ON TABLE public.restaurants TO anon, authenticated;
GRANT SELECT ON TABLE public.restaurant_images TO anon, authenticated;

DROP POLICY IF EXISTS "Restaurants are viewable by everyone" ON public.restaurants;
DROP POLICY IF EXISTS "Restaurants are viewable by users" ON public.restaurants;
CREATE POLICY "Restaurants are viewable by users"
  ON public.restaurants
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Restaurant images are viewable by everyone." ON public.restaurant_images;
DROP POLICY IF EXISTS "Restaurant images are viewable by users" ON public.restaurant_images;
CREATE POLICY "Restaurant images are viewable by users"
  ON public.restaurant_images
  FOR SELECT
  TO anon, authenticated
  USING (true);

ALTER TABLE public.restaurants DROP COLUMN IF EXISTS is_approved;
