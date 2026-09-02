-- Admin hard delete for restaurants.
--
-- The admin console only soft-deletes (deleted_at). For records that must be
-- removed permanently, this RPC deletes a restaurant and its pipeline-owned
-- child rows in one transaction. It is SECURITY DEFINER so it can bypass the
-- missing table-level DELETE grants/policies for `authenticated`, but the
-- caller must still be an admin.
--
-- User-generated content is preserved:
--   posts.restaurant_id is ON DELETE SET NULL (posts survive, just unlinked).
-- reviews / bookmarks for these restaurants are deleted only because the
-- restaurant itself no longer exists (FK would otherwise block).

CREATE OR REPLACE FUNCTION public.admin_hard_delete_restaurants(p_restaurant_ids bigint[])
RETURNS TABLE (deleted_id bigint, deleted_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'admin_hard_delete_restaurants: caller is not an admin';
  END IF;

  CREATE TEMP TABLE _hard_deleted (deleted_id bigint, deleted_name text) ON COMMIT DROP;

  -- Pipeline-owned children (no cascade on their FKs).
  DELETE FROM public.restaurant_social_posts   WHERE restaurant_id = ANY (p_restaurant_ids);
  DELETE FROM public.restaurant_social_metrics WHERE restaurant_id = ANY (p_restaurant_ids);
  DELETE FROM public.restaurant_images         WHERE restaurant_id = ANY (p_restaurant_ids);
  DELETE FROM public.restaurant_sources        WHERE restaurant_id = ANY (p_restaurant_ids);

  -- User-generated posts are preserved: just unlink them (the posts FK lost
  -- its original ON DELETE SET NULL behaviour in the v2 migration).
  UPDATE public.posts SET restaurant_id = NULL WHERE restaurant_id = ANY (p_restaurant_ids);

  -- Community rows that would block the delete (none expected for scraped data).
  DELETE FROM public.reviews   WHERE restaurant_id = ANY (p_restaurant_ids);
  DELETE FROM public.bookmarks WHERE restaurant_id = ANY (p_restaurant_ids);

  -- Capture names before deleting, for the return value.
  INSERT INTO _hard_deleted (deleted_id, deleted_name)
  SELECT id, name FROM public.restaurants WHERE id = ANY (p_restaurant_ids);

  DELETE FROM public.restaurants WHERE id = ANY (p_restaurant_ids);

  RETURN QUERY SELECT * FROM _hard_deleted;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_hard_delete_restaurants(bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_hard_delete_restaurants(bigint[]) TO authenticated;
