-- Grant SELECT to both anon and authenticated roles on all public tables.
-- Tables created via CLI migrations did not inherit Supabase's default
-- privileges, so these roles hit "permission denied" even though RLS
-- policies allow access.  RLS only gates access; the role still needs
-- the underlying table GRANT.

GRANT SELECT ON public.restaurants TO anon, authenticated;
GRANT SELECT ON public.restaurant_categories TO anon, authenticated;
GRANT SELECT ON public.restaurant_images TO anon, authenticated;
GRANT SELECT ON public.restaurant_menu TO anon, authenticated;
GRANT SELECT ON public.categories TO anon, authenticated;
GRANT SELECT ON public.reviews TO anon, authenticated;
GRANT SELECT ON public.posts TO anon, authenticated;
GRANT SELECT ON public.comments TO anon, authenticated;
GRANT SELECT ON public.likes TO anon, authenticated;
GRANT SELECT ON public.bookmarks TO anon, authenticated;
GRANT SELECT ON public.achievements TO anon, authenticated;
GRANT SELECT ON public.user_achievements TO anon, authenticated;
GRANT SELECT ON public.journeys TO anon, authenticated;
GRANT SELECT ON public.users TO anon, authenticated;
GRANT SELECT ON public.notifications TO anon, authenticated;
GRANT SELECT ON public.reports TO anon, authenticated;
