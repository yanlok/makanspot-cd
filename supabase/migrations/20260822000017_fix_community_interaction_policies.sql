-- Allow authenticated users to manage only their own saved posts.
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can save posts" ON public.bookmarks;
CREATE POLICY "Users can save posts"
  ON public.bookmarks FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id AND post_id IS NOT NULL);

DROP POLICY IF EXISTS "Users can remove saved posts" ON public.bookmarks;
CREATE POLICY "Users can remove saved posts"
  ON public.bookmarks FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Keep comment deletion restricted to the comment author.
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can delete own comments" ON public.comments;
CREATE POLICY "Users can delete own comments"
  ON public.comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

GRANT INSERT, DELETE ON public.bookmarks TO authenticated;
GRANT DELETE ON public.comments TO authenticated;
