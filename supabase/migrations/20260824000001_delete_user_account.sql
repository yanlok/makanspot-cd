-- Allows a signed-in user to permanently delete their own account.
-- Runs with SECURITY DEFINER so it can access auth.users (admin-only table).
-- Deleting from auth.users cascades to public.users and all dependent tables
-- (reviews, posts, comments, likes, bookmarks, journeys, etc.) via FK rules.
create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'No signed-in user.';
  end if;

  -- Remove profile data first (in case FK does not cascade to auth.users).
  delete from public.users where id = uid;

  -- Remove the auth account (cascades any remaining references).
  delete from auth.users where id = uid;
end;
$$;

-- Allow authenticated users to invoke the function.
grant execute on function public.delete_current_user() to authenticated;
