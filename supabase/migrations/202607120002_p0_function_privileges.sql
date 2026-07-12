-- P0 privilege boundary for legacy RPCs. PREPARE ONLY.
-- Review the preflight query in P0_RUNBOOK.md against production before apply.

begin;

do $migration$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (
        p.proname like 'marino\_%' escape '\'
        or p.proname in ('start_game','tap_coin','collect_income','upgrade_building','request_reward')
      )
      and p.proname not in ('marino_current_telegram_id','marino_is_admin','marino_secure_rpc','marino_admin_rpc')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn.signature);
    if exists (
      select 1 from pg_proc p2
      where p2.oid = fn.signature::oid and p2.prosecdef
    ) then
      execute format('alter function %s set search_path = pg_catalog, public', fn.signature);
    end if;
  end loop;
end
$migration$;

-- Puzzle answers are intentionally server-internal. No client role receives EXECUTE.
revoke execute on function public.marino_get_today_combo() from public, anon, authenticated;
revoke execute on function public.marino_get_today_cipher() from public, anon, authenticated;
revoke execute on function public.marino_connect_wallet(text,text) from public, anon, authenticated;

-- Existing P0 feature tables are never exposed through PostgREST directly.
alter table if exists public.marino_daily_combo enable row level security;
alter table if exists public.marino_daily_cipher enable row level security;
alter table if exists public.marino_player_boosts enable row level security;
alter table if exists public.marino_wallets enable row level security;

revoke all on table public.marino_daily_combo from public, anon, authenticated;
revoke all on table public.marino_daily_cipher from public, anon, authenticated;
revoke all on table public.marino_player_boosts from public, anon, authenticated;
revoke all on table public.marino_wallets from public, anon, authenticated;

-- Explicitly retain no RLS policies for client roles: access is through audited RPCs only.
commit;
