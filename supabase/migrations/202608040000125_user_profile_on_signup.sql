-- Automatically create a public.users profile whenever a new auth user
-- registers. This keeps the profile table (which references auth.users)
-- populated without the client having to insert its own row.
--
-- The trigger runs SECURITY DEFINER so it bypasses RLS; the existing
-- "Users can insert their own profile." policy is therefore not required,
-- and no client-side privilege on public.users is needed for signup.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, username, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', NEW.email),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();