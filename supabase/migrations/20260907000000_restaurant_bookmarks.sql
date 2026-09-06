-- Allow saving restaurants (not just posts) to the bookmarks table.
-- The table already has a restaurant_id column; the INSERT policy was the
-- only thing preventing restaurant-only rows.

DROP POLICY IF EXISTS "Users can save posts" ON public.bookmarks;
CREATE POLICY "Users can save posts"
  ON public.bookmarks FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (post_id IS NOT NULL OR restaurant_id IS NOT NULL)
  );

-- A user may save a given restaurant at most once.
CREATE UNIQUE INDEX IF NOT EXISTS bookmarks_one_restaurant_per_user_idx
  ON public.bookmarks (user_id, restaurant_id)
  WHERE restaurant_id IS NOT NULL;
