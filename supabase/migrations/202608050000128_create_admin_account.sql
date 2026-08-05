-- 202608050000128_create_admin_account.sql
--
-- Creates the MakanSpot administrator account used by the admin console.
-- Idempotent: safe to run multiple times.
--
-- Credentials mirror the admin console's demo login:
--   email:    admin@makanspot.my
--   password: admin123
-- These are public demo credentials already hard-coded in the app, not
-- production secrets.

-- ─── 0. Ensure pgcrypto is available ──────────────────────────────────
-- crypt()/gen_salt() come from pgcrypto. On Supabase it is pre-installed
-- in the extensions schema; elsewhere it is created in the first schema
-- on the search path (public). Putting both schemas on the search path
-- makes the functions resolvable in either case.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path = public, extensions;

-- ─── 1. Create the admin auth account ────────────────────────────────
-- Newer GoTrue versions no longer have a unique constraint on
-- auth.users.email, so guard the insert with NOT EXISTS instead of
-- ON CONFLICT.
-- The token columns must be '' (not NULL) or GoTrue sign-in fails with
-- "Database error querying schema".
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token,
  email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@makanspot.my',
  crypt('admin123', gen_salt('bf')),
  now(),
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"username":"admin"}'::jsonb,
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'admin@makanspot.my'
);

-- ─── 2. Link an email identity (behaves like a normal sign-up) ──────
INSERT INTO auth.identities (
  id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
SELECT
  gen_random_uuid(),
  u.id,
  u.id::text,
  jsonb_build_object('sub', u.id::text, 'email', u.email),
  'email',
  now(), now(), now()
FROM auth.users u
WHERE u.email = 'admin@makanspot.my'
  AND NOT EXISTS (
    SELECT 1 FROM auth.identities i
    WHERE i.user_id = u.id AND i.provider = 'email'
  );

-- ─── 3. Promote the profile to the admin role ────────────────────────
-- The on_auth_user_created trigger creates the public.users profile row;
-- this also covers projects where the trigger already ran or is absent.
INSERT INTO public.users (id, username, email, role)
SELECT
  u.id,
  COALESCE(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1)),
  u.email,
  'admin'
FROM auth.users u
WHERE u.email = 'admin@makanspot.my'
ON CONFLICT (id) DO UPDATE SET role = 'admin';
