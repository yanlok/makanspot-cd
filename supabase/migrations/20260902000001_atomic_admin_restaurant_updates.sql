-- Keep sensitive account fields immutable for non-admin users. Existing admins
-- retain the account-management access granted by earlier migrations.
CREATE OR REPLACE FUNCTION public.prevent_non_admin_sensitive_user_updates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_role text;
BEGIN
  IF auth.role() <> 'authenticated' THEN
    RETURN NEW;
  END IF;

  SELECT users.role
    INTO actor_role
    FROM public.users
    WHERE users.id = auth.uid();

  IF actor_role IS DISTINCT FROM 'admin'
     AND (
       NEW.role IS DISTINCT FROM OLD.role
       OR NEW.is_active IS DISTINCT FROM OLD.is_active
       OR NEW.community_score IS DISTINCT FROM OLD.community_score
     ) THEN
    RAISE EXCEPTION 'Only administrators can update protected account fields'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.prevent_non_admin_sensitive_user_updates()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS protect_sensitive_user_fields ON public.users;
CREATE TRIGGER protect_sensitive_user_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_non_admin_sensitive_user_updates();

-- Update restaurant details and their primary image in one transaction so the
-- admin UI cannot report failure after partially committing restaurant fields.
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
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE users.id = auth.uid()
      AND users.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Administrator access required'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.restaurants
  SET name = p_name,
      normalized_name = p_normalized_name,
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
      categories = COALESCE(p_categories, '{}'::text[]),
      business_hours = p_business_hours,
      updated_at = now()
  WHERE id = p_restaurant_id;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  IF affected_rows = 0 THEN
    RETURN false;
  END IF;

  IF p_image_url IS NOT NULL AND btrim(p_image_url) <> '' THEN
    SELECT id
      INTO primary_image_id
      FROM public.restaurant_images
      WHERE restaurant_id = p_restaurant_id
        AND is_primary = true
      LIMIT 1;

    SELECT id
      INTO matching_image_id
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
      INSERT INTO public.restaurant_images (
        restaurant_id,
        image_url,
        is_primary
      ) VALUES (
        p_restaurant_id,
        btrim(p_image_url),
        true
      );
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
