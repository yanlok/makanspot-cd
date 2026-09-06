-- Validate values inside the privileged update RPC as well as in the client.
-- This prevents malformed edits and concurrent duplicate names from being
-- persisted by a caller that bypasses the Flutter form.

-- The original restaurant table predates the admin console. Add the console's
-- canonical fields and copy legacy contact/hours values so a valid save does
-- not fail with a missing-column database error.
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS instagram_username text,
  ADD COLUMN IF NOT EXISTS instagram_location_id text,
  ADD COLUMN IF NOT EXISTS categories text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS business_hours jsonb,
  ADD COLUMN IF NOT EXISTS verification_confidence numeric(3, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

UPDATE public.restaurants
SET phone = coalesce(phone, phone_number),
    business_hours = coalesce(business_hours, operating_hours),
    updated_at = coalesce(updated_at, last_updated, created_at)
WHERE phone IS NULL
   OR business_hours IS NULL
   OR updated_at IS NULL;

-- A potential duplicate is identified from any of the restaurant identity
-- fields. The edited record's ID is excluded, so retaining its own values is
-- always allowed. Descriptive fields such as price, hours, and description
-- are deliberately not identifiers and may legitimately be shared.
CREATE OR REPLACE FUNCTION public.admin_restaurant_duplicate_exists(
  p_restaurant_id bigint,
  p_name text,
  p_address text,
  p_city text,
  p_state text,
  p_latitude double precision,
  p_longitude double precision,
  p_phone text,
  p_website text,
  p_instagram_username text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  normalized_restaurant_name text := lower(
    regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g')
  );
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.restaurants AS restaurant
    WHERE restaurant.id <> p_restaurant_id
      AND (
        restaurant.normalized_name = normalized_restaurant_name
        OR (
          nullif(btrim(p_phone), '') IS NOT NULL
          AND btrim(coalesce(restaurant.phone, '')) = btrim(p_phone)
        )
        OR (
          nullif(btrim(p_website), '') IS NOT NULL
          AND lower(btrim(coalesce(restaurant.website, ''))) =
              lower(btrim(p_website))
        )
        OR (
          nullif(btrim(p_instagram_username), '') IS NOT NULL
          AND lower(btrim(coalesce(restaurant.instagram_username, ''))) =
              lower(btrim(p_instagram_username))
        )
        OR (
          nullif(btrim(p_address), '') IS NOT NULL
          AND lower(btrim(coalesce(restaurant.address, ''))) =
              lower(btrim(p_address))
          AND coalesce(lower(btrim(restaurant.city)), '') =
              coalesce(lower(btrim(p_city)), '')
          AND coalesce(lower(btrim(restaurant.state)), '') =
              coalesce(lower(btrim(p_state)), '')
        )
        OR (
          p_latitude IS NOT NULL
          AND p_longitude IS NOT NULL
          AND restaurant.latitude IS NOT DISTINCT FROM p_latitude
          AND restaurant.longitude IS NOT DISTINCT FROM p_longitude
        )
      )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_restaurant_duplicate_exists(
  bigint, text, text, text, text, double precision, double precision,
  text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_restaurant_duplicate_exists(
  bigint, text, text, text, text, double precision, double precision,
  text, text, text
) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_restaurant(
  p_restaurant_id bigint,
  p_name text,
  p_normalized_name text,
  p_description text,
  p_address text,
  p_city text,
  p_state text,
  p_latitude double precision,
  p_longitude double precision,
  p_phone text,
  p_website text,
  p_price_range text,
  p_instagram_username text,
  p_categories text[],
  p_business_hours jsonb,
  p_image_url text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  affected_rows integer;
  primary_image_id bigint;
  matching_image_id bigint;
  normalized_restaurant_name text := lower(
    regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g')
  );
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
  END IF;

  IF normalized_restaurant_name = ''
     OR (p_phone IS NOT NULL AND p_phone !~ '^01\d-\d{7}$')
     OR (
       p_website IS NOT NULL
       AND btrim(p_website) <> ''
       AND btrim(p_website) !~* '^https?://[^[:space:]]+$'
     )
     OR (p_latitude IS NOT NULL AND (p_latitude < -90 OR p_latitude > 90))
     OR (p_longitude IS NOT NULL AND (p_longitude < -180 OR p_longitude > 180))
     OR (p_business_hours IS NOT NULL AND CASE
       WHEN jsonb_typeof(p_business_hours) <> 'object' THEN true
       ELSE EXISTS (
         SELECT 1
         FROM jsonb_each_text(p_business_hours) AS business_hours(day, hours)
         WHERE day !~ '^[^:;]+$'
           OR hours !~ '^([01][0-9]|2[0-3]):[0-5][0-9]\s*-\s*([01][0-9]|2[0-3]):[0-5][0-9]$'
       )
     END) THEN
    RAISE EXCEPTION 'Invalid restaurant information' USING ERRCODE = '22023';
  END IF;

  IF public.admin_restaurant_duplicate_exists(
    p_restaurant_id,
    p_name,
    p_address,
    p_city,
    p_state,
    p_latitude,
    p_longitude,
    p_phone,
    p_website,
    p_instagram_username
  ) THEN
    RAISE EXCEPTION 'A similar restaurant record already exists'
      USING ERRCODE = '23505';
  END IF;

  UPDATE public.restaurants
  SET name = p_name,
      normalized_name = normalized_restaurant_name,
      description = p_description,
      address = p_address,
      city = p_city,
      state = p_state,
      latitude = p_latitude,
      longitude = p_longitude,
      phone = p_phone,
      website = p_website,
      price_range = p_price_range,
      instagram_username = p_instagram_username,
      categories = coalesce(p_categories, '{}'::text[]),
      business_hours = p_business_hours,
      updated_at = now()
  WHERE id = p_restaurant_id;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  IF affected_rows = 0 THEN
    RETURN false;
  END IF;

  IF p_image_url IS NOT NULL AND btrim(p_image_url) <> '' THEN
    SELECT id INTO primary_image_id
    FROM public.restaurant_images
    WHERE restaurant_id = p_restaurant_id AND is_primary = true
    LIMIT 1;

    SELECT id INTO matching_image_id
    FROM public.restaurant_images
    WHERE restaurant_id = p_restaurant_id
      AND image_url = btrim(p_image_url)
    LIMIT 1;

    IF matching_image_id IS NOT NULL THEN
      IF primary_image_id IS DISTINCT FROM matching_image_id THEN
        UPDATE public.restaurant_images
        SET is_primary = false
        WHERE id = primary_image_id;

        UPDATE public.restaurant_images
        SET is_primary = true
        WHERE id = matching_image_id;
      END IF;
    ELSIF primary_image_id IS NOT NULL THEN
      UPDATE public.restaurant_images
      SET image_url = btrim(p_image_url)
      WHERE id = primary_image_id;
    ELSE
      INSERT INTO public.restaurant_images (restaurant_id, image_url, is_primary)
      VALUES (p_restaurant_id, btrim(p_image_url), true);
    END IF;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_restaurant(
  bigint, text, text, text, text, text, text, double precision,
  double precision, text, text, text, text, text[], jsonb, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_restaurant(
  bigint, text, text, text, text, text, text, double precision,
  double precision, text, text, text, text, text[], jsonb, text
) TO authenticated;
