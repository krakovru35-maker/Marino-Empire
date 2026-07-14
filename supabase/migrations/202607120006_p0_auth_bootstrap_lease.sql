-- Short, service-role-only lease for serializing first Telegram identity bootstrap.
-- PREPARE ONLY; do not apply automatically.

begin;

create table if not exists public.marino_auth_bootstrap_leases (
  telegram_id text primary key check (telegram_id ~ '^[1-9][0-9]{0,19}$'),
  lease_token uuid not null,
  expires_at timestamptz not null,
  lease_started_at timestamptz not null default now(),
  check (expires_at <= lease_started_at + interval '30 seconds')
);

alter table public.marino_auth_bootstrap_leases enable row level security;
revoke all on table public.marino_auth_bootstrap_leases from public, anon, authenticated;

create or replace function public.marino_acquire_auth_bootstrap_lease(
  p_telegram_id text,
  p_lease_token uuid,
  p_lease_seconds integer default 10
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_acquired boolean := false;
begin
  if p_telegram_id !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_telegram_id'; end if;
  if p_lease_token is null then raise exception 'lease_token_required'; end if;
  if p_lease_seconds not between 5 and 30 then raise exception 'invalid_lease_seconds'; end if;

  insert into public.marino_auth_bootstrap_leases(
    telegram_id, lease_token, expires_at, lease_started_at
  ) values (
    p_telegram_id, p_lease_token,
    clock_timestamp() + make_interval(secs => p_lease_seconds), clock_timestamp()
  )
  on conflict (telegram_id) do update set
    lease_token = excluded.lease_token,
    expires_at = excluded.expires_at,
    lease_started_at = excluded.lease_started_at
  where public.marino_auth_bootstrap_leases.expires_at <= clock_timestamp()
     or public.marino_auth_bootstrap_leases.lease_token = excluded.lease_token
  returning true into v_acquired;

  return coalesce(v_acquired, false);
end
$$;

create or replace function public.marino_release_auth_bootstrap_lease(
  p_telegram_id text,
  p_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_released boolean := false;
begin
  if p_telegram_id !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_telegram_id'; end if;
  if p_lease_token is null then raise exception 'lease_token_required'; end if;

  delete from public.marino_auth_bootstrap_leases
  where telegram_id = p_telegram_id and lease_token = p_lease_token
  returning true into v_released;
  return coalesce(v_released, false);
end
$$;

revoke all on function public.marino_acquire_auth_bootstrap_lease(text,uuid,integer)
  from public, anon, authenticated;
revoke all on function public.marino_release_auth_bootstrap_lease(text,uuid)
  from public, anon, authenticated;
grant execute on function public.marino_acquire_auth_bootstrap_lease(text,uuid,integer)
  to service_role;
grant execute on function public.marino_release_auth_bootstrap_lease(text,uuid)
  to service_role;

commit;
