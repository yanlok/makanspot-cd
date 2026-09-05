-- Users may comment on a post or reply to another user's comment, but cannot
-- reply to one of their own comments.
DROP POLICY IF EXISTS "Users can comment" ON public.comments;
CREATE POLICY "Users can comment"
  ON public.comments FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND (
      parent_comment_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.comments AS parent_comment
        WHERE parent_comment.id = comments.parent_comment_id
          AND parent_comment.post_id = comments.post_id
          AND parent_comment.user_id <> (SELECT auth.uid())
      )
    )
  );
