-- Add a persisted archive state for user-owned posts.
-- This keeps archived posts in My Posts without deleting them.

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active', 'archived'));

UPDATE public.posts
SET status = 'active'
WHERE status IS NULL;
