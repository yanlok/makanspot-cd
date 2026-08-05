-- 202608050000130_reports_soft_delete.sql
--
-- Soft-deletes dismissed reports instead of removing them from the
-- table. Dismissing sets dismissed_at; the moderation queries filter
-- those rows out so dismissed reports leave the queue but stay in the
-- database for audit.

ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS dismissed_at TIMESTAMPTZ;
