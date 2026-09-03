-- Make the restaurant edit permission check independent of users-table RLS.
-- The Flutter client still uses the normal authenticated Supabase request;
-- authorization is enforced here for the signed-in admin account.

CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND lower(trim(role)) = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;

-- Repair the known console account if an older trigger created its profile
-- with the default user role. This does not grant access to other accounts.
UPDATE public.users
SET role = 'admin'
WHERE lower(trim(email)) = 'admin@makanspot.my'
  AND role IS DISTINCT FROM 'admin';

GRANT UPDATE ON TABLE public.restaurants TO authenticated;
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;

-- Remove the broad legacy policy from the initial schema. Leaving multiple
-- policies active makes the effective UPDATE rule depend on migration order.
DROP POLICY IF EXISTS "Only admins can insert/update restaurants."
  ON public.restaurants;
DROP POLICY IF EXISTS "Admins can update restaurant records"
  ON public.restaurants;
CREATE POLICY "Admins can update restaurant records"
  ON public.restaurants FOR UPDATE
  TO authenticated
  USING (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

GRANT INSERT, UPDATE ON TABLE public.restaurant_images TO authenticated;
ALTER TABLE public.restaurant_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can insert restaurant images"
  ON public.restaurant_images;
CREATE POLICY "Admins can insert restaurant images"
  ON public.restaurant_images FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can update restaurant images"
  ON public.restaurant_images;
CREATE POLICY "Admins can update restaurant images"
  ON public.restaurant_images FOR UPDATE
  TO authenticated
  USING (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

-- Use one authenticated, admin-checked write operation for the edit screen.
-- SECURITY DEFINER is intentional: the function performs its own role check
-- and avoids policy evaluation being blocked by the public.users policy.
CREATE OR REPLACE FUNCTION public.update_restaurant_admin(
  p_restaurant_id BIGINT,
  p_changes JSONB
)
RETURNS SETOF public.restaurants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_user() THEN
    RAISE EXCEPTION 'Only administrators can update restaurants'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  UPDATE public.restaurants
  SET name = CASE WHEN p_changes ? 'name' THEN p_changes->>'name' ELSE name END,
      description = CASE WHEN p_changes ? 'description'
        THEN NULLIF(p_changes->>'description', '') ELSE description END,
      address = CASE WHEN p_changes ? 'address' THEN p_changes->>'address' ELSE address END,
      latitude = CASE WHEN p_changes ? 'latitude'
        THEN (p_changes->>'latitude')::DOUBLE PRECISION ELSE latitude END,
      longitude = CASE WHEN p_changes ? 'longitude'
        THEN (p_changes->>'longitude')::DOUBLE PRECISION ELSE longitude END,
      phone_number = CASE WHEN p_changes ? 'phone_number'
        THEN NULLIF(p_changes->>'phone_number', '') ELSE phone_number END,
      owner_name = CASE WHEN p_changes ? 'owner_name'
        THEN NULLIF(p_changes->>'owner_name', '') ELSE owner_name END,
      price_range = CASE WHEN p_changes ? 'price_range'
        THEN NULLIF(p_changes->>'price_range', '') ELSE price_range END,
      rating = CASE WHEN p_changes ? 'rating'
        THEN (p_changes->>'rating')::NUMERIC ELSE rating END,
      operating_hours = CASE WHEN p_changes ? 'operating_hours'
        THEN p_changes->'operating_hours' ELSE operating_hours END,
      social_media_source = CASE WHEN p_changes ? 'social_media_source'
        THEN NULLIF(p_changes->>'social_media_source', '') ELSE social_media_source END,
      is_approved = CASE WHEN p_changes ? 'is_approved'
        THEN (p_changes->>'is_approved')::BOOLEAN ELSE is_approved END,
      last_updated = NOW()
  WHERE id = p_restaurant_id
  RETURNING *;

  IF p_changes ? 'cuisine' THEN
    DELETE FROM public.restaurant_categories
    WHERE restaurant_id = p_restaurant_id;

    INSERT INTO public.restaurant_categories (restaurant_id, category_id)
    SELECT p_restaurant_id, c.id
    FROM public.categories AS c
    WHERE c.name = ANY (
      ARRAY(SELECT jsonb_array_elements_text(p_changes->'cuisine'))
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_restaurant_admin(BIGINT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_restaurant_admin(BIGINT, JSONB) TO authenticated;

-- Reload after the RPC exists so PostgREST exposes the function immediately.
NOTIFY pgrst, 'reload schema';
