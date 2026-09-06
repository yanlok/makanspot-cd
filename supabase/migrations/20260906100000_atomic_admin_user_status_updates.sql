-- Persist a user-account status change and its administrative audit entry in
-- the same database transaction. If either step fails, the account remains
-- in its former state and the Flutter UI can show the relevant failure message.

CREATE OR REPLACE FUNCTION public.audit_admin_user_account_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_username text;
BEGIN
  IF NEW.is_active IS NOT DISTINCT FROM OLD.is_active THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = auth.uid() AND actor.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
  END IF;

  SELECT actor.username
    INTO actor_username
    FROM public.users AS actor
    WHERE actor.id = auth.uid();

  INSERT INTO public.admin_audit_log (
    admin_user_id,
    admin_username,
    action,
    target_user_id,
    target_username,
    field_changes
  ) VALUES (
    auth.uid(),
    actor_username,
    'toggle_account_status',
    NEW.id,
    NEW.username,
    jsonb_build_object(
      'is_active',
      jsonb_build_object('from', OLD.is_active, 'to', NEW.is_active)
    )
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_admin_user_account_status_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS audit_admin_user_account_status_change ON public.users;
CREATE TRIGGER audit_admin_user_account_status_change
  AFTER UPDATE OF is_active ON public.users
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION public.audit_admin_user_account_status_change();
