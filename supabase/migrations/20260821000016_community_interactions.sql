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