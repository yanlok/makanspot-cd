-- Grant the Edge Function role write access to the tables the enrichment
-- pipeline promotes into. Same root cause as 20260722000006: tables created via
-- CLI migrations did not inherit Supabase's default privileges, so service_role
-- hit "permission denied for table restaurants" when inserting.
--
-- These tables already have public SELECT via RLS policies; this only adds the
-- server-side (service_role) write access used by the Edge Functions.

GRANT ALL ON TABLE public.restaurants TO service_role;
GRANT ALL ON TABLE public.restaurant_images TO service_role;
