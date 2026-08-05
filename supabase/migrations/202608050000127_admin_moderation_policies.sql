-- 202608050000127_admin_moderation_policies.sql
--
-- Lets admins hide reported content from public view by updating
-- is_hidden on posts and comments.
--
-- The original posts policy only allowed the content owner to update
-- ("Users can update/delete own posts."), and comments had no UPDATE
-- policy at all, so the admin's moderation updates silently matched
-- zero rows.

DROP POLICY IF EXISTS "Admins can hide content" ON public.posts;
CREATE POLICY "Admins can hide content"
  ON public.posts FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can hide content" ON public.comments;
CREATE POLICY "Admins can hide content"
  ON public.comments FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
