-- 20260804160000_seed_community_posts.sql
--
-- Seeds the community feed with demo users, restaurant images,
-- posts, likes, and comments.  Safe to run multiple times.
-- Uses service_role privileges (bypasses RLS).

-- ─── 1. Demo auth users ──────────────────────────────────────────────
-- The on_auth_user_created trigger auto-creates public.users rows.
-- Password for all demo accounts: password123
INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
SELECT
  v.id,
  v.email,
  extensions.crypt('password123', extensions.gen_salt('bf')),
  now(),
  '{}'::jsonb,
  jsonb_build_object('username', v.username),
  now(),
  now()
FROM (VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'fariz@makan.my',  'fariz_foods'),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901'::uuid, 'siti@makan.my',   'siti_eats'),
  ('c3d4e5f6-a7b8-9012-cdef-123456789012'::uuid, 'ahmad@makan.my',  'ahmad_makan')
) AS v(id, email, username)
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users u WHERE u.id = v.id
);

-- ─── 2. Restaurant images ────────────────────────────────────────────
-- The community query joins restaurant_images to display post photos.
INSERT INTO public.restaurant_images (restaurant_id, image_url, is_primary)
SELECT r.id, img.url, img.is_primary
FROM public.restaurants r
JOIN (
  VALUES
    ('Village Park Nasi Lemak',    'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800', true),
    ('Sisters Curry Mee',          'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?w=800', true),
    ('Restoran Kin Kin',           'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800', true),
    ('Ali, Muthu & Ah Hock',      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800', true),
    ('Burp & Giggles',             'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?w=800', true),
    ('Soong Kee Beef Noodles',     'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800', true),
    ('Nasi Lemak Wanjo',           'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800', true),
    ('Brickfields Pisang Goreng',  'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=800', true)
) AS img(name, url, is_primary)
ON r.name = img.name
WHERE NOT EXISTS (
  SELECT 1 FROM public.restaurant_images ri
  WHERE ri.restaurant_id = r.id AND ri.is_primary = true
);

-- ─── 3. Community posts ──────────────────────────────────────────────
-- Timestamps are spread across the last 4 days for a realistic feed.
INSERT INTO public.posts (user_id, restaurant_id, content, rating, media_urls, created_at)
SELECT
  u.id,
  r.id,
  p.content,
  p.rating,
  p.media_urls,
  now() - (p.age || ' hours')::interval
FROM (VALUES
  ('fariz@makan.my', 'Village Park Nasi Lemak',
   'Finally tried Village Park and wow, the nasi lemak here is next level! The fried chicken is crispy and the sambal has the perfect kick. Highly recommend for anyone visiting Damansara Uptown.',
   5, ARRAY['https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800']::text[], 2),
  ('siti@makan.my', 'Restoran Kin Kin',
   'The chilli pan mee here is the real deal. Dry version with the crispy chilli topping — absolutely addictive! Been coming here since I was a kid.',
   4, ARRAY['https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800']::text[], 5),
  ('ahmad@makan.my', 'Sisters Curry Mee',
   'Penang curry mee at its finest. The broth is rich and coconutty, topped with fresh cockles and tofu puffs. Worth the drive to George Town!',
   5, ARRAY['https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?w=800']::text[], 24),
  ('fariz@makan.my', 'Ali, Muthu & Ah Hock',
   'Great kopitiam vibes! The nasi lemak here is solid and the white coffee is strong. Perfect breakfast spot in the city centre.',
   4, ARRAY['https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800']::text[], 48),
  ('siti@makan.my', 'Burp & Giggles',
   'Hidden gem in Ipoh! The burgers are massive and the ambiance is so quirky. Love the wall art and the chill atmosphere. A must-visit when in Ipoh.',
   4, ARRAY['https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?w=800']::text[], 72),
  ('ahmad@makan.my', 'Soong Kee Beef Noodles',
   'The beef noodles here are incredible — springy noodles with savoury minced beef in a comforting broth. Simple but so satisfying. One of KL''s best kept secrets!',
   5, ARRAY['https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800']::text[], 96)
) AS p(user_email, restaurant_name, content, rating, media_urls, age)
JOIN auth.users au ON au.email = p.user_email
JOIN public.users u ON u.id = au.id
JOIN public.restaurants r ON r.name = p.restaurant_name
WHERE NOT EXISTS (
  SELECT 1 FROM public.posts existing
  WHERE existing.user_id = u.id
    AND existing.restaurant_id = r.id
    AND existing.content = p.content
);

-- ─── 4. Likes ────────────────────────────────────────────────────────
-- Each post gets 2 likes from the other demo users.
INSERT INTO public.likes (post_id, user_id)
SELECT p.id, u.id
FROM public.posts p
JOIN public.users u ON u.id != p.user_id
WHERE (
  p.content LIKE '%Village Park%' AND u.username IN ('siti_eats', 'ahmad_makan')
) OR (
  p.content LIKE '%Kin Kin%' AND u.username IN ('fariz_foods', 'ahmad_makan')
) OR (
  p.content LIKE '%Sisters%' AND u.username IN ('fariz_foods', 'siti_eats')
) OR (
  p.content LIKE '%Ali, Muthu%' AND u.username IN ('siti_eats', 'ahmad_makan')
) OR (
  p.content LIKE '%Burp%' AND u.username IN ('fariz_foods', 'ahmad_makan')
) OR (
  p.content LIKE '%Soong Kee%' AND u.username IN ('fariz_foods', 'siti_eats')
)
ON CONFLICT DO NOTHING;

-- ─── 5. Comments ─────────────────────────────────────────────────────
INSERT INTO public.comments (post_id, user_id, content, created_at)
SELECT p.id, u.id, c.content, now() - (c.age || ' hours')::interval
FROM (VALUES
  ('%Village Park%', 'siti_eats',  'I love this place too! Their sambal is the best.', 1),
  ('%Kin Kin%',      'fariz_foods', 'The dry version is a must! Try adding the egg next time.', 4),
  ('%Sisters%',      'ahmad_makan', 'Best curry mee in Penang, hands down!', 20)
) AS c(post_pattern, username, content, age)
JOIN public.posts p ON p.content LIKE c.post_pattern
JOIN public.users u ON u.username = c.username
WHERE NOT EXISTS (
  SELECT 1 FROM public.comments existing
  WHERE existing.post_id = p.id
    AND existing.user_id = u.id
    AND existing.content = c.content
);

-- ─── 6. Community scores ─────────────────────────────────────────────
UPDATE public.users
SET community_score = CASE
  WHEN username = 'fariz_foods'  THEN 150
  WHEN username = 'siti_eats'    THEN 120
  WHEN username = 'ahmad_makan'  THEN 200
  ELSE community_score
END
WHERE username IN ('fariz_foods', 'siti_eats', 'ahmad_makan');
