-- Enable authenticated administrators to edit restaurant records and keep an
-- audit trail in the same transaction as each database change.
--
-- This migration is intentionally idempotent so it can also be pasted into
-- the Supabase SQL editor after a partial/failed deployment.

-- ---------------------------------------------------------------------------
-- Editable columns used by the admin console
-- ---------------------------------------------------------------------------

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS normalized_name TEXT,
  ADD COLUMN IF NOT EXISTS owner_name TEXT,
  ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2),
  ADD COLUMN IF NOT EXISTS social_media_source TEXT;

-- Keep the database's duplicate key in sync even when a caller forgets to
-- submit normalized_name or submits an incorrect value.
CREATE OR REPLACE FUNCTION public.set_restaurant_normalized_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.normalized_name := lower(
    regexp_replace(btrim(NEW.name), '\s+', ' ', 'g')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_restaurant_normalized_name
  ON public.restaurants;
CREATE TRIGGER set_restaurant_normalized_name
  BEFORE INSERT OR UPDATE OF name, normalized_name
  ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_restaurant_normalized_name();

UPDATE public.restaurants
SET normalized_name = lower(regexp_replace(btrim(name), '\s+', ' ', 'g'))
WHERE normalized_name IS DISTINCT FROM
  lower(regexp_replace(btrim(name), '\s+', ' ', 'g'));

-- The unique index is the final protection against concurrent duplicate
-- saves. Do not make the rest of this migration fail when pre-existing
-- duplicates need manual review; the UI's duplicate check remains available
-- and rerunning this migration creates the index after those rows are fixed.
DO $$
BEGIN
  IF to_regclass('public.restaurants_normalized_name_unique') IS NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.restaurants
      WHERE normalized_name IS NOT NULL AND btrim(normalized_name) <> ''
      GROUP BY normalized_name
      HAVING count(*) > 1
    ) THEN
      RAISE WARNING
        'Skipped restaurants_normalized_name_unique: duplicate restaurant names already exist';
    ELSE
      CREATE UNIQUE INDEX restaurants_normalized_name_unique
        ON public.restaurants (normalized_name)
        WHERE normalized_name IS NOT NULL AND btrim(normalized_name) <> '';
    END IF;
  END IF;
END;
$$;

-- Add a database guard for new rating values without blocking deployment when
-- an older database already contains out-of-range legacy data.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.restaurants'::regclass
      AND conname = 'restaurants_rating_range'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM public.restaurants
      WHERE rating IS NOT NULL AND (rating < 0 OR rating > 5)
    ) THEN
      RAISE WARNING
        'Skipped restaurants_rating_range: out-of-range legacy ratings exist';
    ELSE
      ALTER TABLE public.restaurants
        ADD CONSTRAINT restaurants_rating_range
        CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5));
    END IF;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- Restaurant and cover-image permissions
-- ---------------------------------------------------------------------------

GRANT UPDATE ON TABLE public.restaurants TO authenticated;
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can update restaurant records"
  ON public.restaurants;
CREATE POLICY "Admins can update restaurant records"
  ON public.restaurants FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

GRANT INSERT, UPDATE ON TABLE public.restaurant_images TO authenticated;
ALTER TABLE public.restaurant_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can insert restaurant images"
  ON public.restaurant_images;
CREATE POLICY "Admins can insert restaurant images"
  ON public.restaurant_images FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update restaurant images"
  ON public.restaurant_images;
CREATE POLICY "Admins can update restaurant images"
  ON public.restaurant_images FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Sequence names can differ after restores or manual schema changes. Resolve
-- the actual identity/serial sequences instead of assuming their names. A
-- UUID or otherwise sequence-free id needs no grant.
DO $$
DECLARE
  sequence_name TEXT;
BEGIN
  sequence_name := pg_get_serial_sequence(
    'public.restaurant_images',
    'id'
  );
  IF sequence_name IS NOT NULL THEN
    EXECUTE format(
      'GRANT USAGE, SELECT ON SEQUENCE %s TO authenticated',
      to_regclass(sequence_name)
    );
  END IF;

  sequence_name := pg_get_serial_sequence(
    'public.admin_audit_log',
    'id'
  );
  IF sequence_name IS NOT NULL THEN
    EXECUTE format(
      'GRANT USAGE, SELECT ON SEQUENCE %s TO authenticated',
      to_regclass(sequence_name)
    );
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- Restaurant audit target and automatic audit entries
-- ---------------------------------------------------------------------------

ALTER TABLE public.admin_audit_log
  ADD COLUMN IF NOT EXISTS target_restaurant_id BIGINT
    REFERENCES public.restaurants (id) ON DELETE SET NULL;

GRANT SELECT, INSERT ON TABLE public.admin_audit_log TO authenticated;

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target_restaurant
  ON public.admin_audit_log (target_restaurant_id);

-- Derive the audit diff from OLD and NEW so logs describe the values actually
-- persisted by PostgreSQL. Bookkeeping-only changes are excluded. Current and
-- legacy schema column names are mapped to the labels used by the admin UI.
CREATE OR REPLACE FUNCTION public.audit_admin_restaurant_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  admin_id UUID := auth.uid();
  admin_name TEXT;
  changes JSONB;
BEGIN
  IF admin_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(u.username, ''), NULLIF(u.email, ''), admin_id::TEXT)
  INTO admin_name
  FROM public.users AS u
  WHERE u.id = admin_id AND u.role = 'admin';

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
    jsonb_object_agg(
      CASE new_value.key
        WHEN 'categories' THEN 'cuisine'
        WHEN 'business_hours' THEN 'operating_hours'
        WHEN 'phone' THEN 'contact'
        WHEN 'phone_number' THEN 'contact'
        WHEN 'price_range' THEN 'budget'
        WHEN 'social_media_source' THEN 'source_platform'
        WHEN 'verification_confidence' THEN 'verification_status'
        WHEN 'is_approved' THEN 'verification_status'
        ELSE new_value.key
      END,
      jsonb_build_object('from', old_value.value, 'to', new_value.value)
    ),
    '{}'::JSONB
  )
  INTO changes
  FROM jsonb_each(to_jsonb(NEW)) AS new_value
  JOIN jsonb_each(to_jsonb(OLD)) AS old_value
    ON old_value.key = new_value.key
  WHERE new_value.key NOT IN (
      'normalized_name',
      'updated_at',
      'last_updated'
    )
    AND new_value.value IS DISTINCT FROM old_value.value;

  IF changes = '{}'::JSONB THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.admin_audit_log (
    admin_user_id,
    admin_username,
    action,
    target_restaurant_id,
    target_username,
    field_changes
  ) VALUES (
    admin_id,
    admin_name,
    'update_restaurant',
    NEW.id,
    NEW.name,
    changes
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_admin_restaurant_update() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.audit_admin_restaurant_update()
  FROM anon, authenticated;

DROP TRIGGER IF EXISTS audit_admin_restaurant_update
  ON public.restaurants;
CREATE TRIGGER audit_admin_restaurant_update
  AFTER UPDATE ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_admin_restaurant_update();

-- Cover images live in a related table and are saved by a separate REST
-- request. Audit that mutation at its own table boundary so every image change
-- and its audit row are still atomic with each other.
CREATE OR REPLACE FUNCTION public.audit_admin_restaurant_image_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  admin_id UUID := auth.uid();
  admin_name TEXT;
  restaurant_name TEXT;
  old_image_url TEXT;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.image_url IS NOT DISTINCT FROM OLD.image_url THEN
      RETURN NEW;
    END IF;
    old_image_url := OLD.image_url;
  END IF;

  IF admin_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(u.username, ''), NULLIF(u.email, ''), admin_id::TEXT)
  INTO admin_name
  FROM public.users AS u
  WHERE u.id = admin_id AND u.role = 'admin';

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT r.name
  INTO restaurant_name
  FROM public.restaurants AS r
  WHERE r.id = NEW.restaurant_id;

  INSERT INTO public.admin_audit_log (
    admin_user_id,
    admin_username,
    action,
    target_restaurant_id,
    target_username,
    field_changes
  ) VALUES (
    admin_id,
    admin_name,
    'update_restaurant',
    NEW.restaurant_id,
    COALESCE(restaurant_name, 'Restaurant ' || NEW.restaurant_id::TEXT),
    jsonb_build_object(
      'image_url',
      jsonb_build_object('from', old_image_url, 'to', NEW.image_url)
    )
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_admin_restaurant_image_change()
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.audit_admin_restaurant_image_change()
  FROM anon, authenticated;

DROP TRIGGER IF EXISTS audit_admin_restaurant_image_insert
  ON public.restaurant_images;
CREATE TRIGGER audit_admin_restaurant_image_insert
  AFTER INSERT ON public.restaurant_images
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_admin_restaurant_image_change();

DROP TRIGGER IF EXISTS audit_admin_restaurant_image_update
  ON public.restaurant_images;
CREATE TRIGGER audit_admin_restaurant_image_update
  AFTER UPDATE OF image_url ON public.restaurant_images
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_admin_restaurant_image_change();

-- Make the new optional columns and trigger functions visible to PostgREST
-- immediately after this script is run from the Supabase SQL editor.
NOTIFY pgrst, 'reload schema';
