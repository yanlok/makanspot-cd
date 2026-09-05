-- Migrate posts with unknown or deleted restaurants to existing random active restaurants.
WITH candidates AS (
  SELECT id AS restaurant_id, row_number() OVER (ORDER BY random()) AS rn
  FROM public.restaurants
  WHERE deleted_at IS NULL
),
targets AS (
  SELECT id AS post_id, row_number() OVER (ORDER BY id) AS rn
  FROM public.posts
  WHERE restaurant_id IS NULL
     OR NOT EXISTS (
       SELECT 1
       FROM public.restaurants r
       WHERE r.id = posts.restaurant_id
         AND r.deleted_at IS NULL
     )
)
UPDATE public.posts p
SET restaurant_id = c.restaurant_id
FROM targets t
JOIN candidates c ON t.rn = c.rn
WHERE p.id = t.post_id;
