-- Users may comment on another user's post or reply to another user's comment,
-- but cannot comment on their own posts or reply to one of their own comments.
-- SECURITY DEFINER helpers prevent infinite recursion during RLS evaluation.

CREATE OR REPLACE FUNCTION public.can_comment_on_post(
  p_post_id bigint,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.posts
    WHERE id = p_post_id
      AND user_id <> p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.can_reply_to_comment(
  p_parent_comment_id bigint,
  p_post_id bigint,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.comments
    WHERE id = p_parent_comment_id
      AND post_id = p_post_id
      AND user_id <> p_user_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_comment_on_post(bigint, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_reply_to_comment(bigint, bigint, uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can comment" ON public.comments;
CREATE POLICY "Users can comment"
  ON public.comments FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.uid() = user_id)
    AND (
      (parent_comment_id IS NULL AND public.can_comment_on_post(post_id, auth.uid()))
      OR public.can_reply_to_comment(parent_comment_id, post_id, auth.uid())
    )
  );
