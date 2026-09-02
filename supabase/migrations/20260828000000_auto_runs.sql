-- ============================================================================
-- Auto Runs: sequential query rotation for the data scraper pipeline
-- ============================================================================

-- Status enum for auto-run sessions
CREATE TYPE auto_run_status AS ENUM (
  'pending',   -- created, not yet started
  'running',   -- actively processing queries
  'paused',    -- current scrape run will finish, but no new queries start
  'completed', -- all eligible queries processed or limit reached
  'failed',    -- unrecoverable error
  'stopped'    -- manually stopped by admin
);

-- Auto-run session tracking
CREATE TABLE auto_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status auto_run_status NOT NULL DEFAULT 'pending',

  -- Configuration
  config JSONB NOT NULL DEFAULT '{
    "results_per_query": 30,
    "max_queries": 10,
    "cost_limit_usd": 5.00
  }',

  -- Progress tracking
  current_query_source_id INTEGER REFERENCES discovery_sources(id),
  queries_completed INTEGER NOT NULL DEFAULT 0,

  -- Restaurant-level results (the key metrics from the enhancement plan)
  new_restaurants INTEGER NOT NULL DEFAULT 0,
  existing_matched INTEGER NOT NULL DEFAULT 0,
  skipped_no_image INTEGER NOT NULL DEFAULT 0,
  failed_candidates INTEGER NOT NULL DEFAULT 0,

  -- Cost tracking
  total_cost_usd NUMERIC(10,4) NOT NULL DEFAULT 0,

  -- Link to the currently active scrape run (null between queries)
  current_scrape_run_id UUID REFERENCES scrape_runs(id),

  -- Stop tracking
  stop_reason TEXT,

  -- Timestamps
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Link individual scrape runs back to their auto-run session
ALTER TABLE scrape_runs ADD COLUMN auto_run_id UUID REFERENCES auto_runs(id);

-- Indexes for quick lookups
CREATE INDEX idx_auto_runs_status ON auto_runs(status) WHERE status IN ('pending', 'running', 'paused');
CREATE INDEX idx_scrape_runs_auto_run ON scrape_runs(auto_run_id) WHERE auto_run_id IS NOT NULL;
