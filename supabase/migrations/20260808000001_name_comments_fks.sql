-- 20260808000001_name_comments_fks.sql
--
-- Names the comments foreign keys explicitly so PostgREST can resolve
-- the comment -> post relationship in joins. The posts foreign keys
-- were named for the same reason in 20260715000002_fix_post_relationships.sql.

-- ─── 1. Name the comments -> posts foreign key ──────────────────────
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.comments'::regclass
      AND confrelid = 'public.posts'::regclass
      AND contype = 'f';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.comments DROP CONSTRAINT ' || constraint_name;
    END IF;
END $$;

ALTER TABLE public.comments
ADD CONSTRAINT comments_post_id_fkey
FOREIGN KEY (post_id)
REFERENCES public.posts(id)
ON DELETE CASCADE;

-- ─── 2. Name the comments -> users foreign key ──────────────────────
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.comments'::regclass
      AND confrelid = 'public.users'::regclass
      AND contype = 'f';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.comments DROP CONSTRAINT ' || constraint_name;
    END IF;
END $$;

ALTER TABLE public.comments
ADD CONSTRAINT comments_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES public.users(id)
ON DELETE CASCADE;
