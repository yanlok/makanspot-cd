-- 20260820000001_profile_avatar_bucket.sql
--
-- Supports the Profile and Edit Profile screens:
--   * adds a bio column so users can share a short introduction, and
--   * creates a public avatars storage bucket with per-user folders so a
--     signed-in user can upload their own profile picture.
--
-- Updates to username / avatar_url / bio are already covered by the existing
-- "Users can update own profile." RLS policy (auth.uid() = id); only the
-- column-level UPDATE grant below is extended.

-- ─── 1. Add bio column ─────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS bio TEXT;

-- ─── 2. Grant user-editable columns to authenticated ──────────────────
-- Re-issued to cover fresh installs and to include bio alongside the
-- original username / avatar_url grant made in earlier migrations.
GRANT UPDATE (username, email, phone_number, avatar_url, bio, country,
              favorite_food, community_score, role, is_active, updated_at)
  ON public.users TO authenticated;

-- ─── 3. Public avatars bucket ─────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880, -- 5 MB per file
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
    SET public = EXCLUDED.public,
        file_size_limit = EXCLUDED.file_size_limit,
        allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Users may upload into their own folder (avatars/<uid>/...).
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Object owners can replace or delete their avatar.
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- The bucket is public-read, so avatars load directly by URL. A SELECT
-- policy also lets the Supabase client list an object (e.g. getPublicUrl).
DROP POLICY IF EXISTS "Avatars are viewable by everyone" ON storage.objects;
CREATE POLICY "Avatars are viewable by everyone"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');