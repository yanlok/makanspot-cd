-- 202608050000131_seed_more_reports.sql
--
-- Seeds additional pending post reports so the moderation console has a
-- fuller showcase. References the demo posts and users created by
-- 20260804160000_seed_community_posts.sql. Safe to run multiple times
-- (each insert is guarded by NOT EXISTS).

-- ─── 1. Kin Kin chilli pan mee post (siti_eats) ───────────────────────
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Duplicate content',
  'The same review text appears on another restaurant page.',
  now() - interval '2 days'
FROM public.users u, public.posts p
WHERE u.username = 'ahmad_makan' AND p.content LIKE '%Kin Kin%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.reporter_id = u.id AND r.post_id = p.id
      AND r.reason = 'Duplicate content'
  )
LIMIT 1;

-- ─── 2. Ali, Muthu & Ah Hock post (fariz_foods) ───────────────────────
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Off-topic or advertising',
  'Reads like an advertisement for the kopitiam rather than a genuine review.',
  now() - interval '1 day'
FROM public.users u, public.posts p
WHERE u.username = 'siti_eats' AND p.content LIKE '%Ali, Muthu%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.reporter_id = u.id AND r.post_id = p.id
      AND r.reason = 'Off-topic or advertising'
  )
LIMIT 1;

-- ─── 3. Soong Kee post (ahmad_makan) ──────────────────────────────────
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Misleading information',
  'Calls the restaurant "one of KL''s best kept secrets" although it is widely listed everywhere.',
  now() - interval '6 hours'
FROM public.users u, public.posts p
WHERE u.username = 'fariz_foods' AND p.content LIKE '%Soong Kee%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.reporter_id = u.id AND r.post_id = p.id
      AND r.reason = 'Misleading information'
  )
LIMIT 1;

-- ─── 4. Village Park post — third report (showcases report count) ─────
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Spam or misleading promotion',
  'Promotional language that repeatedly pushes the restaurant brand.',
  now() - interval '20 hours'
FROM public.users u, public.posts p
WHERE u.username = 'fariz_foods' AND p.content LIKE '%Village Park%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.reporter_id = u.id AND r.post_id = p.id
      AND r.reason = 'Spam or misleading promotion'
  )
LIMIT 1;

-- ─── 5. Sisters Curry Mee post — second report (showcases count) ──────
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id,
  'Misleading information',
  'The 5-star rating looks inflated compared with recent visitor photos.',
  now() - interval '3 days'
FROM public.users u, public.posts p
WHERE u.username = 'siti_eats' AND p.content LIKE '%Sisters%'
  AND NOT EXISTS (
    SELECT 1 FROM public.reports r
    WHERE r.reporter_id = u.id AND r.post_id = p.id
      AND r.reason = 'Misleading information'
  )
LIMIT 1;
