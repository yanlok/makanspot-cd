-- Allow comments to form one level of reply threads.
ALTER TABLE public.comments
  ADD COLUMN parent_comment_id BIGINT REFERENCES public.comments(id) ON DELETE CASCADE;
CREATE INDEX comments_post_parent_created_at_idx
  ON public.comments (post_id, parent_comment_id, created_at);
