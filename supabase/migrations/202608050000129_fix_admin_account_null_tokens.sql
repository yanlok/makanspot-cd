-- 202608050000129_fix_admin_account_null_tokens.sql
--
-- GoTrue fails sign-in with "Database error querying schema" when the
-- token columns of auth.users are NULL instead of empty strings. Direct
-- SQL inserts (like 202608050000128) leave them NULL.
--
-- See: https://supabase.com/docs/guides/troubleshooting/auth-error-500-database-error-querying-schema-eb6b44

UPDATE auth.users
SET confirmation_token = '',
    recovery_token = '',
    email_change_token_new = '',
    email_change = ''
WHERE email = 'admin@makanspot.my'
  AND (confirmation_token IS NULL
       OR recovery_token IS NULL
       OR email_change_token_new IS NULL
       OR email_change IS NULL);
