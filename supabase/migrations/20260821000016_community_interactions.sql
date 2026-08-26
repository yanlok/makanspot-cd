ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS reports_one_per_user_post_idx
  ON public.reports (reporter_id, post_id)
  WHERE post_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS reports_one_per_user_comment_idx
  ON public.reports (reporter_id, comment_id)
  WHERE comment_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS bookmarks_one_post_per_user_idx
  ON public.bookmarks (user_id, post_id)
  WHERE post_id IS NOT NULL;

GRANT UPDATE, DELETE ON public.comments TO authenticated;

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can delete own comments" ON public.comments;
CREATE POLICY "Users can delete own comments"
  ON public.comments FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can pin comments on own posts" ON public.comments;
CREATE POLICY "Users can pin comments on own posts"
  ON public.comments FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = comments.post_id AND posts.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = comments.post_id AND posts.user_id = auth.uid()
    )
  );