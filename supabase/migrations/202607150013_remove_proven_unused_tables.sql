-- Remove only production-verified empty, unreferenced legacy tables.
-- RESTRICT is intentional: any newly introduced dependency aborts this migration.
begin;

do $$
begin
  if exists(select 1 from public.marino_in_game_notifications limit 1) then raise exception 'cleanup_blocked_marino_in_game_notifications_not_empty'; end if;
  if exists(select 1 from public.marino_ad_reward_logs limit 1) then raise exception 'cleanup_blocked_marino_ad_reward_logs_not_empty'; end if;
  if exists(select 1 from public.marino_sink_purchases limit 1) then raise exception 'cleanup_blocked_marino_sink_purchases_not_empty'; end if;
end $$;

drop table public.marino_in_game_notifications restrict;
drop table public.marino_ad_reward_logs restrict;
drop table public.marino_sink_purchases restrict;

commit;
