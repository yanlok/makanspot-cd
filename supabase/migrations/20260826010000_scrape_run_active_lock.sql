-- Database-enforced single active paid scrape. This closes the race between
-- the trigger's read check and insert. Failed/completed history is unaffected.
DO $$
BEGIN
  IF (SELECT count(*) FROM public.scrape_runs WHERE status IN ('pending', 'running')) > 1 THEN
    RAISE EXCEPTION 'Cannot install active-run lock while multiple runs are active; cancel them through cancel-pipeline first';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS scrape_runs_one_active_run
  ON public.scrape_runs ((true))
  WHERE status IN ('pending', 'running');
