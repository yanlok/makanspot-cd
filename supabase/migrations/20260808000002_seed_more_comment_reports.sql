-- 20260808000002_seed_more_comment_reports.sql
--
-- Seeds extra reported comments so the admin "Reported Comments" tab
-- demonstrates pending, multi-report, and removed states.
-- Safe to run multiple times.

-- ─── 1. Pending comment with two reports (spam) ─────────────────────
INSERT INTO public.comments (post_id, user_id, content, created_at)
SELECT p.id, u.id, 'DM me for free vouchers at every restaurant in KL!',
       now() - interval '18 hours'
FROM public.posts p
JOIN public.users u ON u.username = 'siti_eats'
WHERE p.content LIKE '%Village Park%'
  AND NOT EXISTS (
    SELECT 1 FROM public.comments c
    WHERE c.post_id = p.id AND c.content LIKE '%DM me for free vouchers%'
  )
LIMIT 1;

INSERT INTO public.reports (reporter_id, comment_id, reason, additional_info, created_at)
SELECT u.id, c.id,
  'Spam or misleading promotion',
  'Repeated promotional message in the comments.',
  now() - interval '16 hours'
FROM public.users u, public.comments c
WHERE u.username = 'fariz_foods'
  AND c.content LIKE '%DM me for free vouchers%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.comment_id = c.id
  )
LIMIT 1;

INSERT INTO public.reports (reporter_id, comment_id, reason, additional_info, created_at)
SELECT u.id, c.id,
  'Spam or misleading promotion',
  'Comment links to external promotions.',
  now() - interval '14 hours'
FROM public.users u, public.comments c
WHERE u.username = 'ahmad_makan'
  AND c.content LIKE '%DM me for free vouchers%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.comment_id = c.id
  )
LIMIT 1;

-- ─── 2. Removed comment (admin already hid it) with a report ────────
INSERT INTO public.comments (post_id, user_id, content, created_at)
SELECT p.id, u.id, 'Full guide with all my secret spots: tinyurl.com/makan-free-meals',
       now() - interval '5 days'
FROM public.posts p
JOIN public.users u ON u.username = 'fariz_foods'
WHERE p.content LIKE '%Sisters%'
  AND NOT EXISTS (
    SELECT 1 FROM public.comments c
    WHERE c.post_id = p.id AND c.content LIKE '%tinyurl.com%'
  )
LIMIT 1;

UPDATE public.comments SET is_hidden = true WHERE content LIKE '%tinyurl.com%';

INSERT INTO public.reports (reporter_id, comment_id, reason, additional_info, created_at)
SELECT u.id, c.id,
  'Spam or misleading promotion',
  'Multiple community members reported the promotional link.',
  now() - interval '6 days'
FROM public.users u, public.comments c
WHERE u.username = 'siti_eats'
  AND c.content LIKE '%tinyurl.com%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r WHERE r.reporter_id = u.id AND r.comment_id = c.id
  )
LIMIT 1;
