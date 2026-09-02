-- Grant service_role full access to pipeline_jobs.
-- Same root cause as 20260722000006/000008: tables created via CLI migrations
-- do not inherit Supabase's default privileges, so the Edge Functions
-- (service_role) hit "permission denied for table pipeline_jobs".

GRANT ALL ON TABLE public.pipeline_jobs TO service_role;
