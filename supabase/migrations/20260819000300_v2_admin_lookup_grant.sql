-- Allow V2 Edge Functions to verify the caller's database-backed admin role.
-- RLS is still bypassed only by the backend service role; clients receive no
-- additional access to public.users from this grant.
GRANT SELECT ON TABLE public.users TO service_role;
