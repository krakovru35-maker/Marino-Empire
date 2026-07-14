-- P0 security foundation. PREPARE ONLY; do not apply automatically.
-- This migration is additive and does not delete existing player data.

begin;

create table if not exists public.marino_identity_links (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  telegram_id text not null unique check (telegram_id ~ '^[1-9][0-9]{0,19}$'),
  telegram_username text check (telegram_username is null or telegram_username ~ '^[A-Za-z0-9_]{5,32}$'),
  display_name text not null default '' check (char_length(display_name) <= 128),
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.marino_admin_roles (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('support', 'operator', 'security_admin')),
  active boolean not null default true,
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  check (expires_at is null or expires_at > granted_at)
);

create table if not exists public.marino_admin_audit_log (
  id bigint generated always as identity primary key,
  auth_user_id uuid not null references auth.users(id),
  action text not null check (action ~ '^[a-z][a-z0-9_]{2,63}$'),
  target_id text,
  request_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (auth_user_id, request_id)
);

create table if not exists public.marino_idempotency_keys (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  action text not null check (action ~ '^[a-z][a-z0-9_]{2,63}$'),
  response jsonb,
  created_at timestamptz not null default now(),
  primary key (auth_user_id, request_id)
);

create index if not exists marino_idempotency_created_idx
  on public.marino_idempotency_keys (created_at);

alter table public.marino_identity_links enable row level security;
alter table public.marino_admin_roles enable row level security;
alter table public.marino_admin_audit_log enable row level security;
alter table public.marino_idempotency_keys enable row level security;

-- No client policies are created: direct API access is deny-by-default.
revoke all on table public.marino_identity_links from public, anon, authenticated;
revoke all on table public.marino_admin_roles from public, anon, authenticated;
revoke all on table public.marino_admin_audit_log from public, anon, authenticated;
revoke all on table public.marino_idempotency_keys from public, anon, authenticated;

create or replace function public.marino_current_telegram_id()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select links.telegram_id
  from public.marino_identity_links as links
  where links.auth_user_id = auth.uid()
    and links.last_verified_at > now() - interval '24 hours'
$$;

create or replace function public.marino_is_admin(required_roles text[] default array['support','operator','security_admin']::text[])
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.marino_admin_roles as roles
    where roles.auth_user_id = auth.uid()
      and roles.active
      and roles.role = any(required_roles)
      and (roles.expires_at is null or roles.expires_at > now())
  )
$$;

revoke all on function public.marino_current_telegram_id() from public, anon;
revoke all on function public.marino_is_admin(text[]) from public, anon;
grant execute on function public.marino_current_telegram_id() to authenticated;
grant execute on function public.marino_is_admin(text[]) to authenticated;

commit;
