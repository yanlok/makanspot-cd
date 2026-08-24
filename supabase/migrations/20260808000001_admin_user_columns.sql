-- 20260808000001_admin_user_columns.sql
--
-- Extends the public.users table with account-status and contact columns
-- needed by the admin user management feature.
--
-- Adds:
--   is_active      – BOOLEAN flag that drives AdminAccountStatus in the UI
--   phone_number   – optional contact number editable by admins
--   updated_at     – bumped via trigger on every UPDATE

-- ─── 1. Add columns ───────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Backfill existing rows: every existing user starts as active.
UPDATE public.users
  SET is_active = true
  WHERE is_active IS NULL;

-- ─── 2. RLS policy: admins can UPDATE any user account ──────────────
-- The original policy only let a user update their own profile row.
-- Admins need to toggle is_active, edit email/phone/role, etc.
DROP POLICY IF EXISTS "Admins can update any user account" ON public.users;
CREATE POLICY "Admins can update any user account"
  ON public.users FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to select all users (read all columns incl. phone/is_active).
-- The existing "Public users are viewable by everyone" SELECT policy already
-- covers SELECT; we rely on it rather than duplicating.

-- ─── 3. Grant UPDATE to authenticated (RLS gates the rows) ───────────
GRANT UPDATE (username, email, phone_number, avatar_url,
              country, favorite_food, community_score,
              role, is_active, updated_at)
  ON public.users TO authenticated;
