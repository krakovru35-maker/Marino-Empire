-- Fail closed when the caller has no active Content Operations admin role.

begin;

create or replace function public.content_admin_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce((
    select role
    from public.content_admin_users
    where auth_user_id = auth.uid()
      and active
      and (expires_at is null or expires_at > now())
  ), '')
$$;

revoke all on function public.content_admin_role() from public, anon, authenticated;

commit;
