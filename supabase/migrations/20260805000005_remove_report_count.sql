-- 20260805000005_remove_report_count.sql
--
-- Removes the report_count column from the reports table.
-- Report counts are now derived by grouping reports on the same
-- content (post_id or comment_id).

ALTER TABLE public.reports DROP COLUMN IF EXISTS report_count;
