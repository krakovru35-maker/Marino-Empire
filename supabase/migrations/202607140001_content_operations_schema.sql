-- PHASE 5A content operations schema. PREPARE ONLY; do not apply automatically.
-- All rewards in this schema are virtual/demo rights or Marino Reward Points.

begin;

create extension if not exists pgcrypto with schema extensions;

create table public.content_admin_users (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('viewer','editor','publisher','super_admin')),
  active boolean not null default true,
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  check (expires_at is null or expires_at > granted_at)
);

create table public.daily_content (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('daily_combo','daily_cipher','daily_reward','casino_mission','special_event')),
  title_tr text not null check (char_length(title_tr) between 1 and 160),
  title_en text not null check (char_length(title_en) between 1 and 160),
  description_tr text not null default '' check (char_length(description_tr) <= 2000),
  description_en text not null default '' check (char_length(description_en) <= 2000),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'draft' check (status in ('draft','scheduled','published','expired','cancelled')),
  reward_type text not null default 'none' check (reward_type in ('reward_point','demo_free_spin','demo_free_bet','cosmetic','none')),
  reward_amount integer not null default 0 check (reward_amount between 0 and 1000000),
  answer_hash text,
  answer_normalization text not null default 'nfkc_lower_trim' check (answer_normalization in ('nfkc_lower_trim','nfkc_upper_trim','json_exact')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  version integer not null default 1 check (version > 0),
  check (ends_at > starts_at),
  check ((reward_type = 'none' and reward_amount = 0) or (reward_type <> 'none' and reward_amount > 0)),
  check (not (payload ?| array['answer','solution','correct_answer','combo_order','cipher_answer'])),
  check (content_type not in ('daily_combo','daily_cipher') or answer_hash is not null)
);

create table public.player_content_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.daily_content(id) on delete cascade,
  attempt_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(attempt_payload) = 'object'),
  is_correct boolean not null,
  attempted_at timestamptz not null default now(),
  request_id uuid not null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  unique (user_id, request_id)
);

create table public.player_content_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.daily_content(id) on delete restrict,
  reward_type text not null check (reward_type in ('reward_point','demo_free_spin','demo_free_bet','cosmetic','none')),
  reward_amount integer not null check (reward_amount between 0 and 1000000),
  claim_status text not null default 'claimed' check (claim_status in ('claimed','rejected','revoked')),
  request_id uuid not null,
  claimed_at timestamptz not null default now(),
  entitlement_id uuid,
  unique (user_id, content_id),
  unique (user_id, request_id)
);

create table public.virtual_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entitlement_type text not null check (entitlement_type in ('demo_free_spin','demo_free_bet','cosmetic')),
  quantity integer not null check (quantity between 1 and 100000),
  remaining_quantity integer not null check (remaining_quantity between 0 and quantity),
  source_type text not null check (source_type in ('daily_content','casino_mission','special_event')),
  source_id uuid not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  status text not null default 'active' check (status in ('active','consumed','expired','revoked')),
  created_at timestamptz not null default now(),
  check (expires_at is null or expires_at > starts_at),
  unique (user_id, source_type, source_id, entitlement_type)
);

alter table public.player_content_claims
  add constraint player_content_claims_entitlement_fk
  foreign key (entitlement_id) references public.virtual_entitlements(id) on delete restrict;

create table public.player_reward_point_balances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id),
  action text not null check (action ~ '^[a-z][a-z0-9_]{2,63}$'),
  entity_type text not null check (entity_type ~ '^[a-z][a-z0-9_]{2,63}$'),
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  request_id uuid not null,
  ip_hash text,
  created_at timestamptz not null default now(),
  unique (admin_user_id, request_id)
);

create index daily_content_active_idx on public.daily_content (content_type, starts_at, ends_at) where status = 'published';
create index content_attempt_rate_idx on public.player_content_attempts (user_id, content_id, attempted_at desc);
create index content_claim_user_idx on public.player_content_claims (user_id, claimed_at desc);
create index virtual_entitlement_active_idx on public.virtual_entitlements (user_id, status, expires_at);
create index content_audit_entity_idx on public.admin_audit_log (entity_type, entity_id, created_at desc);

create function public.content_set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

create trigger daily_content_updated_at before update on public.daily_content
for each row execute function public.content_set_updated_at();

alter table public.content_admin_users enable row level security;
alter table public.daily_content enable row level security;
alter table public.player_content_attempts enable row level security;
alter table public.player_content_claims enable row level security;
alter table public.virtual_entitlements enable row level security;
alter table public.player_reward_point_balances enable row level security;
alter table public.admin_audit_log enable row level security;

create policy daily_content_player_active_read on public.daily_content
for select to authenticated
using (status = 'published' and starts_at <= now() and ends_at > now());
create policy content_attempt_owner_read on public.player_content_attempts
for select to authenticated using (user_id = auth.uid());
create policy content_claim_owner_read on public.player_content_claims
for select to authenticated using (user_id = auth.uid());
create policy virtual_entitlement_owner_read on public.virtual_entitlements
for select to authenticated using (user_id = auth.uid());
create policy reward_point_owner_read on public.player_reward_point_balances
for select to authenticated using (user_id = auth.uid());

revoke all on table public.content_admin_users from public, anon, authenticated;
revoke all on table public.daily_content from public, anon, authenticated;
revoke all on table public.player_content_attempts from public, anon, authenticated;
revoke all on table public.player_content_claims from public, anon, authenticated;
revoke all on table public.virtual_entitlements from public, anon, authenticated;
revoke all on table public.player_reward_point_balances from public, anon, authenticated;
revoke all on table public.admin_audit_log from public, anon, authenticated;

grant select (id,content_type,title_tr,title_en,description_tr,description_en,payload,starts_at,ends_at,status,reward_type,reward_amount,published_at,version)
  on public.daily_content to authenticated;
grant select on public.player_content_attempts, public.player_content_claims, public.virtual_entitlements, public.player_reward_point_balances to authenticated;

revoke all on function public.content_set_updated_at() from public, anon, authenticated;

commit;
