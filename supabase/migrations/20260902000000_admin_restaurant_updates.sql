-- Allow signed-in administrators to edit restaurant details and primary images
-- from the Flutter admin console. Public restaurant access remains read-only.

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone DEFAULT null;

CREATE INDEX IF NOT EXISTS idx_restaurants_deleted_at
  ON public.restaurants (deleted_at);

CREATE INDEX IF NOT EXISTS idx_restaurants_name_deleted_at_id
  ON public.restaurants (name, deleted_at, id);

DROP POLICY IF EXISTS "Restaurants are viewable by everyone." ON public.restaurants;
DROP POLICY IF EXISTS "Public restaurant read policy" ON public.restaurants;

CREATE POLICY "Public restaurant read policy"
  ON public.restaurants
  FOR SELECT
  TO anon, authenticated
  USING (deleted_at IS NULL);

-- Admins must also see (and manage) soft-deleted restaurants, so they get an
-- OR-ed read policy that bypasses the public deleted_at IS NULL restriction.
DROP POLICY IF EXISTS "Admins can view all restaurants" ON public.restaurants;
CREATE POLICY "Admins can view all restaurants"
  ON public.restaurants
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  );

GRANT UPDATE ON TABLE public.restaurants TO authenticated;
GRANT INSERT, UPDATE ON TABLE public.restaurant_images TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.v2_restaurant_images_id_seq TO authenticated;

DROP POLICY IF EXISTS "Admins can update restaurants" ON public.restaurants;
CREATE POLICY "Admins can update restaurants"
  ON public.restaurants
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can insert restaurant images" ON public.restaurant_images;
CREATE POLICY "Admins can insert restaurant images"
  ON public.restaurant_images
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update restaurant images" ON public.restaurant_images;
CREATE POLICY "Admins can update restaurant images"
  ON public.restaurant_images
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  );
