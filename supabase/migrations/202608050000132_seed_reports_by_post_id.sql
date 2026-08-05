-- 202608050000132_seed_reports_by_post_id.sql
--
-- Seeds pending post reports by explicit post ID. Content-LIKE matching
-- in 202608050000131 only inserted part of the rows on some databases,
-- so this seeds the remaining showcase reports deterministically.
-- Safe to run multiple times (each insert is guarded by NOT EXISTS on
-- reporter / post / reason, so it never duplicates existing rows).

-- ─── 0. Validate the post IDs exist ──────────────────────────────────
-- Fail loudly instead of silently seeding nothing.
DO $$
DECLARE
  missing_count integer;
BEGIN
  SELECT count(*) INTO missing_count
  FROM unnest(ARRAY[1, 2, 3, 4, 5, 6, 9]::bigint[]) AS ids(id)
  WHERE NOT EXISTS (SELECT 1 FROM public.posts p WHERE p.id = ids.id);
  IF missing_count > 0 THEN
    RAISE EXCEPTION
      'Seed aborted: % of the requested post IDs do not exist in public.posts.',
      missing_count;
  END IF;
END $$;

-- ─── 1. Seed reports by post ID ──────────────────────────────────────
INSERT INTO public.reports (reporter_id, post_id, reason, additional_info, created_at)
SELECT u.id, p.id, v.reason, v.additional_info, now() - (v.age || ' hours')::interval
FROM (VALUES
  (1::bigint, 'ahmad_makan', 'Duplicate content',
   'The same review was posted on another restaurant page.', 30),
  (2::bigint, 'siti_eats',   'Off-topic or advertising',
   'Reads like an advertisement rather than a genuine review.', 26),
  (3::bigint, 'fariz_foods', 'Harassment or abusive language',
   'Language that attacks other community members.', 22),
  (4::bigint, 'ahmad_makan', 'Off-topic or advertising',
   'Promotional language that pushes a brand repeatedly.', 18),
  (5::bigint, 'siti_eats',   'Duplicate content',
   'Identical wording to an earlier post.', 14),
  (6::bigint, 'fariz_foods', 'Duplicate content',
   'Repeated the same recommendation in multiple posts.', 8),
  (9::bigint, 'ahmad_makan', 'Misleading information',
   'Facts in the post do not match the restaurant menu.', 3)
) AS v(post_id, username, reason, additional_info, age)
JOIN public.users u ON u.username = v.username
JOIN public.posts p ON p.id = v.post_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.reports r
  WHERE r.post_id = p.id
    AND r.reporter_id = u.id
    AND r.reason = v.reason
);
