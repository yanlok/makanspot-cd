-- Grant table privileges on the staging table.
-- Tables created through CLI migrations do not always inherit Supabase's
-- default privileges, so the Edge Functions (service_role) can hit
-- "permission denied for table scraped_posts". Grant explicitly.
--
-- Access is still gated: RLS on scraped_posts limits authenticated users to
-- admins; service_role bypasses RLS and is only used server-side by the
-- Edge Functions.

GRANT ALL ON TABLE public.scraped_posts TO service_role;
GRANT SELECT ON TABLE public.scraped_posts TO authenticated;
