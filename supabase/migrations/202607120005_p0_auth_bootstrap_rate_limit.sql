-- Reload-tolerant Telegram authentication bootstrap rate limit. PREPARE ONLY.
-- This limits repeated bootstrap attempts but is not a full initData replay ledger.

begin;

create table if not exists public.marino_auth_bootstrap_limits (
  telegram_id text primary key check (telegram_id ~ '^[1-9][0-9]{0,19}$'),
  window_started_at timestamptz not null default now(),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_query_hash text check (last_query_hash is null or last_query_hash ~ '^[a-f0-9]{64}$'),
  last_seen_at timestamptz not null default now()
);

alter table public.marino_auth_bootstrap_limits enable row level security;
revoke all on table public.marino_auth_bootstrap_limits from public, anon, authenticated;

create or replace function public.marino_check_bootstrap_rate_limit(
  p_telegram_id text,
  p_query_hash text,
  p_max_attempts integer default 10,
  p_window_seconds integer default 300
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_attempt_count integer;
begin
  if p_telegram_id !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_telegram_id'; end if;
  if p_query_hash !~ '^[a-f0-9]{64}$' then raise exception 'invalid_query_hash'; end if;
  if p_max_attempts not between 1 and 100 then raise exception 'invalid_rate_limit'; end if;
  if p_window_seconds not between 60 and 3600 then raise exception 'invalid_rate_window'; end if;

  insert into public.marino_auth_bootstrap_limits(
    telegram_id, window_started_at, attempt_count, last_query_hash, last_seen_at
  ) values (p_telegram_id, now(), 1, p_query_hash, now())
  on conflict (telegram_id) do update set
    window_started_at = case
      when public.marino_auth_bootstrap_limits.window_started_at
        <= now() - make_interval(secs => p_window_seconds)
      then now() else public.marino_auth_bootstrap_limits.window_started_at end,
    attempt_count = case
      when public.marino_auth_bootstrap_limits.window_started_at
        <= now() - make_interval(secs => p_window_seconds)
      then 1 else public.marino_auth_bootstrap_limits.attempt_count + 1 end,
    last_query_hash = excluded.last_query_hash,
    last_seen_at = now()
  returning attempt_count into v_attempt_count;

  return v_attempt_count <= p_max_attempts;
end
$$;

revoke all on function public.marino_check_bootstrap_rate_limit(text,text,integer,integer)
  from public, anon, authenticated;
grant execute on function public.marino_check_bootstrap_rate_limit(text,text,integer,integer)
  to service_role;

commit;
