-- 20260805000006_simplify_reports_add_is_hidden.sql
--
-- Simplifies the reports table and adds is_hidden soft-delete
-- to both posts AND comments.
--
-- Reports table after: id, reporter_id, post_id, comment_id,
-- reason, additional_info, created_at

-- ─── 1. Simplify reports table ─────────────────────────────────────
-- Drop columns that are no longer needed.
-- Re-add comment_id if it was dropped by a previous failed run.
ALTER TABLE public.reports DROP COLUMN IF EXISTS content_preview;
ALTER TABLE public.reports DROP COLUMN IF EXISTS content_owner;
ALTER TABLE public.reports DROP COLUMN IF EXISTS removal_reason;
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_status_check;
ALTER TABLE public.reports DROP COLUMN IF EXISTS status;
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS comment_id BIGINT REFERENCES public.comments ON DELETE CASCADE;

-- ─── 2. Add is_hidden to posts ─────────────────────────────────────
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false;

-- ─── 3. Add is_hidden to comments ──────────────────────────────────
ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false;

-- ─── 4. Update RLS policies ────────────────────────────────────────
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON public.posts;
CREATE POLICY "Posts are viewable by everyone"
  ON public.posts FOR SELECT
  USING (
    is_hidden = false
    OR EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Comments are viewable by everyone" ON public.comments;
CREATE POLICY "Comments are viewable by everyone"
  ON public.comments FOR SELECT
  USING (
    is_hidden = false
    OR EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ─── 5. Re-seed demo data ──────────────────────────────────────────
DELETE FROM public.reports;

-- Pending: 2 reports on same post
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Spam or misleading promotion',
  'The post asks users to share personal contact information.',
  now() - interval '3 days'
FROM public.users u, public.posts p
WHERE u.username = 'siti_eats' AND p.content LIKE '%Village Park%'
LIMIT 1;

INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Harassment or abusive language',
  'Content targets other community members.',
  now() - interval '2 days'
FROM public.users u, public.posts p
WHERE u.username = 'ahmad_makan' AND p.content LIKE '%Village Park%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.post_id = p.id
  )
LIMIT 1;

-- Pending: report on a comment
INSERT INTO public.reports (reporter_id, comment_id, reason, additional_info, created_at)
SELECT u.id, c.id,
  'Harassment or abusive language',
  'Comment contains abusive language towards other users.',
  now() - interval '1 day'
FROM public.users u, public.comments c
WHERE u.username = 'fariz_foods'
  AND c.content LIKE '%love this place%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.comment_id = c.id
  )
LIMIT 1;

-- Pending: single report on another post
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Misleading information',
  'Review seems inaccurate.',
  now() - interval '5 days'
FROM public.users u, public.posts p
WHERE u.username = 'fariz_foods' AND p.content LIKE '%Sisters%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.post_id = p.id
  )
LIMIT 1;

-- Removed post (admin already hid it)
UPDATE public.posts SET is_hidden = true WHERE content LIKE '%Burp%';

INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Spam or misleading promotion',
  'Multiple community members reported repeated advertising links.',
  now() - interval '7 days'
FROM public.users u, public.posts p
WHERE u.username = 'ahmad_makan' AND p.content LIKE '%Burp%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.post_id = p.id
  )
LIMIT 1;
