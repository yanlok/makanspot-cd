-- 1. Ensure the foreign key between posts and restaurants is explicitly named
-- This allows PostgREST to disambiguate relationships in complex joins

-- First, drop the existing constraint if it exists (regardless of name)
-- We find it by looking for the foreign key on posts(restaurant_id)
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.posts'::regclass
      AND confrelid = 'public.restaurants'::regclass
      AND contype = 'f';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.posts DROP CONSTRAINT ' || constraint_name;
    END IF;
END $$;

-- 2. Create the constraint with the specific name used in our Dart code
ALTER TABLE public.posts
ADD CONSTRAINT posts_restaurant_id_fkey
FOREIGN KEY (restaurant_id)
REFERENCES public.restaurants(id)
ON DELETE SET NULL;

-- 3. Also ensure users relationship is named consistently
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.posts'::regclass
      AND confrelid = 'public.users'::regclass
      AND contype = 'f';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.posts DROP CONSTRAINT ' || constraint_name;
    END IF;
END $$;

ALTER TABLE public.posts
ADD CONSTRAINT posts_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES public.users(id)
ON DELETE CASCADE;
