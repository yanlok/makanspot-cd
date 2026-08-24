-- Pipeline jobs table for tracking data scraping jobs
CREATE TABLE IF NOT EXISTS public.pipeline_jobs (
  id UUID PRIMARY KEY,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  mode TEXT DEFAULT 'trending',
  hashtags TEXT[],
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  result JSONB,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Index for quick status lookups
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_status ON public.pipeline_jobs(status);
-- RLS policies
ALTER TABLE public.pipeline_jobs ENABLE ROW LEVEL SECURITY;
-- Allow service role full access
CREATE POLICY "Service role can manage pipeline jobs" ON public.pipeline_jobs
  FOR ALL USING (true) WITH CHECK (true);
