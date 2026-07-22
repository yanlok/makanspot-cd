-- Grant the Edge Function role write access to the category tables so the
-- enrichment pipeline can auto-create categories and link restaurants to them.
-- Same root cause as 20260722000006/8: CLI-created tables did not inherit
-- Supabase's default privileges, so service_role hits "permission denied".
--
-- Public read is already granted via RLS policies (20260722000004); this only
-- adds the server-side (service_role) writes used by the Edge Functions.

GRANT ALL ON TABLE public.categories TO service_role;
GRANT ALL ON TABLE public.restaurant_categories TO service_role;

-- categories.id is an IDENTITY column; grant its sequence too, in case default
-- privileges were not inherited for it either.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
