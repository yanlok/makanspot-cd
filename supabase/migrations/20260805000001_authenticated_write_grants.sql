-- Grant INSERT/UPDATE/DELETE to authenticated role on user-writable tables.
-- RLS policies already enforce row ownership; these grants give the role
-- the underlying table privileges needed to actually write.

GRANT INSERT, UPDATE, DELETE ON public.posts TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.comments TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.likes TO authenticated;
GRANT INSERT, DELETE ON public.bookmarks TO authenticated;
