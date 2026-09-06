-- Remove restaurants through one admin-only, auditable transaction.
-- Community and audit history keeps a restaurant archived; otherwise the
-- pipeline-owned record is removed completely.

CREATE OR REPLACE FUNCTION public.admin_remove_restaurant(
  p_restaurant_id bigint,
  p_reason text,
  p_additional_note text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  restaurant_name text;
  has_historical_records boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
  END IF;

  IF p_reason IS NULL OR p_reason NOT IN (
    'Restaurant Permanently Closed',
    'Duplicate Restaurant Listing',
    'Violation of Platform Policies',
    'Other'
  ) THEN
    RAISE EXCEPTION 'A valid restaurant removal reason is required';
  END IF;

  IF p_reason = 'Other' AND coalesce(btrim(p_additional_note), '') = '' THEN
    RAISE EXCEPTION 'An additional note is required when the reason is Other';
  END IF;

  SELECT name
  INTO restaurant_name
  FROM public.restaurants
  WHERE id = p_restaurant_id
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Restaurant % was not found or is already removed', p_restaurant_id;
  END IF;

  -- These are user or administrator records that should retain their
  -- restaurant relationship. Pipeline data (sources and images) is not
  -- considered historical and can be removed with the restaurant.
  SELECT EXISTS (
    SELECT 1 FROM public.posts WHERE restaurant_id = p_restaurant_id
    UNION ALL
    SELECT 1 FROM public.reviews WHERE restaurant_id = p_restaurant_id
    UNION ALL
    SELECT 1 FROM public.bookmarks WHERE restaurant_id = p_restaurant_id
    UNION ALL
    SELECT 1 FROM public.admin_audit_log
    WHERE target_restaurant_id = p_restaurant_id
  ) INTO has_historical_records;

  IF has_historical_records THEN
    UPDATE public.restaurants
    SET deleted_at = now(), updated_at = now()
    WHERE id = p_restaurant_id;

    INSERT INTO public.admin_audit_log (
      admin_user_id,
      admin_username,
      action,
      target_restaurant_id,
      target_username,
      field_changes
    )
    SELECT
      u.id,
      coalesce(nullif(u.username, ''), nullif(u.email, ''), u.id::text),
      'remove_restaurant',
      p_restaurant_id,
      restaurant_name,
      jsonb_build_object(
        'removal_reason', jsonb_build_object('from', NULL, 'to', p_reason),
        'additional_note', jsonb_build_object(
          'from', NULL,
          'to', nullif(btrim(p_additional_note), '')
        ),
        'disposition', jsonb_build_object('from', 'active', 'to', 'archived')
      )
    FROM public.users AS u
    WHERE u.id = auth.uid();

    RETURN true;
  END IF;

  -- Record the reason before deleting. The audit FK is ON DELETE SET NULL,
  -- while the restaurant name and the reason remain available in the log.
  INSERT INTO public.admin_audit_log (
    admin_user_id,
    admin_username,
    action,
    target_restaurant_id,
    target_username,
    field_changes
  )
  SELECT
    u.id,
    coalesce(nullif(u.username, ''), nullif(u.email, ''), u.id::text),
    'remove_restaurant',
    p_restaurant_id,
    restaurant_name,
    jsonb_build_object(
      'removal_reason', jsonb_build_object('from', NULL, 'to', p_reason),
      'additional_note', jsonb_build_object(
        'from', NULL,
        'to', nullif(btrim(p_additional_note), '')
      ),
      'disposition', jsonb_build_object('from', 'active', 'to', 'removed')
    )
  FROM public.users AS u
  WHERE u.id = auth.uid();

  DELETE FROM public.restaurant_social_posts
    WHERE restaurant_id = p_restaurant_id;
  DELETE FROM public.restaurant_social_metrics
    WHERE restaurant_id = p_restaurant_id;
  DELETE FROM public.restaurant_images
    WHERE restaurant_id = p_restaurant_id;
  DELETE FROM public.restaurant_sources
    WHERE restaurant_id = p_restaurant_id;
  DELETE FROM public.restaurants WHERE id = p_restaurant_id;

  RETURN false;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_remove_restaurant(bigint, text, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_remove_restaurant(bigint, text, text)
  TO authenticated;
