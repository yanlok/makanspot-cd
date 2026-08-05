-- 20260805000003_enhance_reports_table.sql
--
-- Enhances the reports table to support the admin moderation UI.
-- Adds denormalised content fields, comment support, and fixes
-- the status enum to use 'removed' instead of 'resolved'.

-- ─── 1. Add missing columns ─────────────────────────────────────────
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS comment_id BIGINT REFERENCES public.comments ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS content_preview TEXT,
  ADD COLUMN IF NOT EXISTS content_owner TEXT,
  ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS additional_info TEXT,
  ADD COLUMN IF NOT EXISTS removal_reason TEXT;

-- ─── 2. Fix status CHECK constraint ─────────────────────────────────
-- The original constraint used 'resolved'; the Flutter model uses 'removed'.
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_status_check;
ALTER TABLE public.reports
  ADD CONSTRAINT reports_status_check
  CHECK (status IN ('pending', 'removed', 'dismissed'));

-- ─── 3. RLS policies ────────────────────────────────────────────────
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Admins have full access to all reports.
DROP POLICY IF EXISTS "Admins have full access to reports" ON public.reports;
CREATE POLICY "Admins have full access to reports"
  ON public.reports FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Authenticated users can submit reports (for future community feature).
DROP POLICY IF EXISTS "Authenticated users can submit reports" ON public.reports;
CREATE POLICY "Authenticated users can submit reports"
  ON public.reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- Everyone can view reports (needed for admin dashboard).
DROP POLICY IF EXISTS "Reports are viewable by everyone" ON public.reports;
CREATE POLICY "Reports are viewable by everyone"
  ON public.reports FOR SELECT USING (true);

-- ─── 4. Grants ──────────────────────────────────────────────────────
GRANT SELECT ON public.reports TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.reports TO authenticated;
