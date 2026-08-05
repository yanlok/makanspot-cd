-- 20260805000004_seed_reports.sql
--
-- Seeds the reports table with demo moderation data.
-- References real user/post/comment IDs from prior migrations.
-- Safe to run multiple times (uses NOT EXISTS guard).

-- ─── 1. Pending post report (spam) ──────────────────────────────────
INSERT INTO public.reports (
  reporter_id, post_id, content_preview, content_owner,
  reason, additional_info, status, report_count, created_at
)
SELECT
  reporter.id,
  target.id,
  LEFT(target.content, 100),
  (SELECT username FROM public.users WHERE id = target.user_id),
  'Spam or misleading promotion',
  'The post appears to contain promotional content that may mislead readers.',
  'pending',
  3,
  now() - interval '3 days'
FROM public.users reporter
JOIN public.posts target ON target.content LIKE '%Village Park%'
WHERE reporter.username = 'siti_eats'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.post_id = target.id
      AND r.reporter_id = reporter.id
      AND r.reason = 'Spam or misleading promotion'
  )
LIMIT 1;

-- ─── 2. Pending comment report (abuse) ──────────────────────────────
INSERT INTO public.reports (
  reporter_id, comment_id, content_preview, content_owner,
  reason, additional_info, status, report_count, created_at
)
SELECT
  reporter.id,
  target.id,
  LEFT(target.content, 100),
  (SELECT username FROM public.users WHERE id = target.user_id),
  'Harassment or abusive language',
  'The comment contains language that violates community guidelines.',
  'pending',
  2,
  now() - interval '2 days'
FROM public.users reporter
JOIN public.comments target ON target.content LIKE '%love this place%'
WHERE reporter.username = 'ahmad_makan'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.comment_id = target.id
      AND r.reporter_id = reporter.id
  )
LIMIT 1;

-- ─── 3. Dismissed post report (false alarm) ─────────────────────────
INSERT INTO public.reports (
  reporter_id, post_id, content_preview, content_owner,
  reason, additional_info, status, report_count, created_at
)
SELECT
  reporter.id,
  target.id,
  LEFT(target.content, 100),
  (SELECT username FROM public.users WHERE id = target.user_id),
  'Misleading information',
  'Reviewed and found to be a genuine personal opinion with no policy violation.',
  'dismissed',
  1,
  now() - interval '5 days'
FROM public.users reporter
JOIN public.posts target ON target.content LIKE '%Kin Kin%'
WHERE reporter.username = 'fariz_foods'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.post_id = target.id
      AND r.reporter_id = reporter.id
      AND r.reason = 'Misleading information'
  )
LIMIT 1;

-- ─── 4. Removed post report (confirmed violation) ───────────────────
INSERT INTO public.reports (
  reporter_id, post_id, content_preview, content_owner,
  reason, additional_info, status, removal_reason,
  report_count, created_at
)
SELECT
  reporter.id,
  target.id,
  LEFT(target.content, 100),
  (SELECT username FROM public.users WHERE id = target.user_id),
  'Spam or misleading promotion',
  'Multiple community members reported this content as spam.',
  'removed',
  'Content confirmed as spam by multiple community reports.',
  4,
  now() - interval '7 days'
FROM public.users reporter
JOIN public.posts target ON target.content LIKE '%Burp%'
WHERE reporter.username = 'ahmad_makan'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.post_id = target.id
      AND r.reporter_id = reporter.id
      AND r.status = 'removed'
  )
LIMIT 1;
