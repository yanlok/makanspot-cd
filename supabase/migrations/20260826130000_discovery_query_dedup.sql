-- Enforce one canonical active/manual-or-automated search query regardless of
-- case, repeated whitespace, or a leading hashtag. Non-query discovery source
-- types retain their existing uniqueness behavior.
ALTER TABLE public.discovery_sources
  ADD COLUMN IF NOT EXISTS normalized_query text GENERATED ALWAYS AS (
    CASE
      WHEN source_type IN ('search_query', 'automation')
           AND status = 'active' THEN
        lower(
          regexp_replace(
            regexp_replace(btrim(source_value), '^#+\s*', ''),
            '\s+',
            ' ',
            'g'
          )
        )
      ELSE NULL
    END
  ) STORED;

DO $$
BEGIN
  IF EXISTS (
    SELECT normalized_query
    FROM public.discovery_sources
    WHERE normalized_query IS NOT NULL
    GROUP BY normalized_query
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Normalize existing duplicate discovery queries before installing the unique index';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS discovery_sources_normalized_query_unique
  ON public.discovery_sources (normalized_query)
  WHERE normalized_query IS NOT NULL;

-- Serialize changes that activate discovery sources so concurrent suggestion
-- calls cannot exceed the global free/low-cost operating cap.
CREATE OR REPLACE FUNCTION public.enforce_active_discovery_source_cap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'active'
     AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'active') THEN
    PERFORM pg_advisory_xact_lock(
      hashtextextended('discovery_sources_active_cap', 0)
    );
    IF (
      SELECT count(*)
      FROM public.discovery_sources
      WHERE status = 'active'
        AND (TG_OP = 'INSERT' OR id <> NEW.id)
    ) >= 50 THEN
      RAISE EXCEPTION 'Active discovery source cap of 50 reached'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_active_discovery_source_cap
  ON public.discovery_sources;
CREATE TRIGGER enforce_active_discovery_source_cap
BEFORE INSERT OR UPDATE OF status ON public.discovery_sources
FOR EACH ROW EXECUTE FUNCTION public.enforce_active_discovery_source_cap();
