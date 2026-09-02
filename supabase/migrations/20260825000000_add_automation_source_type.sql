-- Add 'automation' to discovery_sources source_type CHECK constraint.
-- This allows AI-suggested search queries to be tracked separately from
-- manually created sources.

-- Drop both possible constraint names (old v2 name and new name)
ALTER TABLE discovery_sources
  DROP CONSTRAINT IF EXISTS discovery_sources_source_type_check;

ALTER TABLE discovery_sources
  DROP CONSTRAINT IF EXISTS v2_discovery_sources_source_type_check;

ALTER TABLE discovery_sources
  ADD CONSTRAINT discovery_sources_source_type_check
  CHECK (source_type IN ('hashtag','account','location','search_query','automation'));
