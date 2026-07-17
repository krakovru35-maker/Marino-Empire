-- Server-authoritative casino task progress. PREPARE ONLY.
-- Apply only after staging validation; this file does not run automatically.

begin;

create table if not exists public.marino_task_progress_rules (
  task_key text primary key references public.marino_tasks(task_key) on delete cascade,
  metric text not null check (metric ~ '^[a-z0-9_]{2,64}$'),
  goal integer not null check (goal between 1 and 100000),
  created_at timestamptz not null default now()
);

create table if not exists public.marino_player_task_progress (
  player_id bigint not null references public.marino_players(id) on delete cascade,
  metric text not null check (metric ~ '^[a-z0-9_]{2,64}$'),
  period_key text not null check (period_key ~ '^(daily:[0-9]{4}-[0-9]{2}-[0-9]{2}|weekly:[0-9]{4}-[0-9]{2}|all)$'),
  progress_value integer not null default 0 check (progress_value >= 0 and progress_value <= 1000000),
  updated_at timestamptz not null default now(),
  primary key (player_id, metric, period_key)
);

alter table public.marino_task_progress_rules enable row level security;
alter table public.marino_player_task_progress enable row level security;

drop policy if exists marino_task_progress_rules_deny_all on public.marino_task_progress_rules;
create policy marino_task_progress_rules_deny_all on public.marino_task_progress_rules for all using (false) with check (false);
drop policy if exists marino_player_task_progress_deny_all on public.marino_player_task_progress;
create policy marino_player_task_progress_deny_all on public.marino_player_task_progress for all using (false) with check (false);

create or replace function public.marino_task_period_key(p_task_type text)
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when p_task_type = 'daily' then 'daily:' || current_date::text
    when p_task_type = 'weekly' then 'weekly:' || to_char(current_date, 'IYYY-IW')
    else 'all'
  end
$$;

revoke all on function public.marino_task_period_key(text) from public, anon, authenticated;

create or replace function public.marino_record_task_progress(p_player_id bigint, p_metric text, p_delta integer default 1)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_delta integer := greatest(1, least(coalesce(p_delta, 1), 1000));
  v_period text;
begin
  if p_player_id is null then raise exception 'invalid_player'; end if;
  if p_metric is null or p_metric !~ '^[a-z0-9_]{2,64}$' then raise exception 'invalid_metric'; end if;
  foreach v_period in array array['daily:' || current_date::text, 'weekly:' || to_char(current_date, 'IYYY-IW'), 'all'] loop
    insert into public.marino_player_task_progress(player_id, metric, period_key, progress_value, updated_at)
    values (p_player_id, p_metric, v_period, v_delta, now())
    on conflict (player_id, metric, period_key) do update
      set progress_value = least(public.marino_player_task_progress.progress_value + excluded.progress_value, 1000000),
          updated_at = now();
  end loop;
end;
$$;

revoke all on function public.marino_record_task_progress(bigint,text,integer) from public, anon, authenticated;

insert into public.marino_tasks(task_key, task_name, description, task_type, reward_coin, reward_token, reward_xp, required_level, sort_order, is_active)
values
  ('slot_spin_5','Beş Spin','Marino Fortune Slots üzerinde 5 server onaylı spin tamamla.','daily',20,0,5,1,210,true),
  ('slot_payline','Kazanan Hat','Slot sonucunda server onaylı kazanan hat gör.','achievement',30,0,8,1,220,true),
  ('roulette_spin_3','Üç Çark','Rulet masasında 3 server onaylı tur tamamla.','daily',20,0,5,1,230,true),
  ('roulette_mix','Masa Bilgisi','Aynı rulet turunda inside ve outside seçim kullan.','weekly',35,0,10,1,240,true),
  ('blackjack_hands_3','Üç El','Blackjack Lounge içinde 3 server onaylı el başlat.','daily',20,0,5,1,250,true)
on conflict(task_key) do update set
  task_name=excluded.task_name, description=excluded.description, task_type=excluded.task_type,
  reward_coin=excluded.reward_coin, reward_token=excluded.reward_token, reward_xp=excluded.reward_xp,
  required_level=excluded.required_level, sort_order=excluded.sort_order, is_active=excluded.is_active;

insert into public.marino_task_progress_rules(task_key, metric, goal)
values
  ('slot_spin_5','slot_spin',5),
  ('slot_payline','slot_payline_win',1),
  ('roulette_spin_3','roulette_spin',3),
  ('roulette_mix','roulette_mix',1),
  ('blackjack_hands_3','blackjack_hand',3)
on conflict(task_key) do update set metric=excluded.metric, goal=excluded.goal;

create or replace function public.marino_claim_task(p_telegram_id text,p_task_id text,p_level_no integer default 1,p_request_id text default '')
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_player public.marino_players%rowtype;
  v_task public.marino_tasks%rowtype;
  v_rule public.marino_task_progress_rules%rowtype;
  v_period text;
  v_progress integer := 0;
  v_reward bigint;
begin
  if p_task_id is null or p_task_id !~ '^[a-z0-9_]{2,64}$' then raise exception 'invalid_task_id'; end if;
  if p_request_id<>'' then
    insert into public.marino_processed_requests(request_id) values(p_request_id) on conflict do nothing;
    if not found then raise exception 'Bu işlem zaten işlendi.'; end if;
  end if;
  select * into v_player from public.marino_players where telegram_id=p_telegram_id for update;
  if not found then raise exception 'Oyuncu bulunamadı.'; end if;
  select * into v_task from public.marino_tasks where task_key=p_task_id and is_active;
  if not found then raise exception 'Görev aktif değil.'; end if;
  if v_player.casino_level<v_task.required_level then raise exception 'Bu görev için seviye % gerekli.',v_task.required_level; end if;
  select * into v_rule from public.marino_task_progress_rules where task_key=p_task_id;
  if found then
    v_period := public.marino_task_period_key(v_task.task_type);
    select progress_value into v_progress from public.marino_player_task_progress
    where player_id=v_player.id and metric=v_rule.metric and period_key=v_period;
    if coalesce(v_progress,0) < v_rule.goal then raise exception 'Görev henüz tamamlanmadı.'; end if;
  end if;
  if v_task.task_type='daily' then
    if exists(select 1 from public.marino_player_tasks where player_id=v_player.id and task_key=p_task_id and claimed_at>=current_date) then raise exception 'Bu günlük görevi bugün zaten tamamladın.'; end if;
    delete from public.marino_player_tasks where player_id=v_player.id and task_key=p_task_id;
  elsif exists(select 1 from public.marino_player_tasks where player_id=v_player.id and task_key=p_task_id) then
    raise exception 'Bu görevi zaten tamamladın.';
  end if;
  v_reward:=v_task.reward_coin;
  insert into public.marino_player_tasks(player_id,task_key) values(v_player.id,p_task_id);
  update public.marino_players set marino_coin=marino_coin+v_task.reward_coin,reward_token=reward_token+v_task.reward_token,
    reputation=reputation+v_task.reward_xp,updated_at=now() where id=v_player.id returning * into v_player;
  return jsonb_build_object('ok',true,'state',jsonb_build_object('marino_coin',v_player.marino_coin,'reward_token',v_player.reward_token,
    'energy',v_player.energy,'max_energy',v_player.max_energy,'tap_power',v_player.tap_power,
    'passive_income_per_hour',v_player.passive_income_per_hour,'casino_level',v_player.casino_level,
    'reputation',v_player.reputation,'claimable_coin',v_player.claimable_coin,
    'offline_capacity_hours',v_player.offline_capacity_hours,'prestige_points',v_player.prestige_points),
    'completed_tasks',(public.marino_task_state()->'completed'),'message','Görev ödülü alındı: +'||v_reward||' coin');
end;
$$;

revoke all on function public.marino_claim_task(text,text,integer,text) from public,anon,authenticated;
create or replace function public.marino_secure_rpc(
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_auth_user uuid := auth.uid();
  v_telegram_id text;
  v_response jsonb;
  v_bet bigint;
  v_player_id bigint;
begin
  if v_auth_user is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  if p_action is null or p_action !~ '^[a-z][a-z0-9_]{2,63}$' then raise exception 'invalid_action'; end if;
  if jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' then raise exception 'invalid_payload'; end if;
  if p_payload ?| array['p_telegram_id','telegram_id','p_admin_id','auth_user_id','role'] then
    raise exception 'caller_identity_not_allowed' using errcode = '42501';
  end if;

  v_telegram_id := public.marino_current_telegram_id();
  if v_telegram_id is null then raise exception 'verified_telegram_session_required' using errcode = '28000'; end if;
  select id into v_player_id from public.marino_players where telegram_id = v_telegram_id;
  if v_player_id is null then raise exception 'player_not_found'; end if;

  if p_request_id is not null then
    select response into v_response
    from public.marino_idempotency_keys
    where auth_user_id = v_auth_user and request_id = p_request_id;
    if found and v_response is not null then return v_response; end if;
    insert into public.marino_idempotency_keys(auth_user_id, request_id, action)
    values (v_auth_user, p_request_id, p_action)
    on conflict do nothing;
    if not found then raise exception 'request_in_progress' using errcode = '40001'; end if;
  end if;

  case p_action
    when 'marino_hk_state' then
      v_response := public.marino_hk_state(v_telegram_id)
        || jsonb_build_object('cipher_hint', public._marino_cipher_hint());
    when 'marino_claim_combo' then
      if jsonb_array_length(coalesce(p_payload->'p_picks','[]'::jsonb)) <> 3 then raise exception 'three_picks_required'; end if;
      v_response := public.marino_claim_combo(v_telegram_id, array(select jsonb_array_elements_text(p_payload->'p_picks')));
    when 'marino_claim_cipher' then
      if coalesce(p_payload->>'p_word','') !~ '^[A-Z]{3,16}$' then raise exception 'invalid_cipher_word'; end if;
      v_response := public.marino_claim_cipher(v_telegram_id, p_payload->>'p_word');
    when 'marino_use_full_energy' then
      v_response := public.marino_use_full_energy(v_telegram_id);
    when 'marino_use_tap_boost' then
      v_response := public.marino_use_tap_boost(v_telegram_id);
    when 'marino_upgrade_multitap' then
      v_response := public.marino_upgrade_multitap(v_telegram_id);
    when 'marino_upgrade_energy_limit' then
      v_response := public.marino_upgrade_energy_limit(v_telegram_id);
    when 'marino_activate_auto_tap' then
      v_response := public.marino_activate_auto_tap(v_telegram_id);
    when 'start_game' then
      if char_length(coalesce(p_payload->>'p_site_username','')) > 32 then raise exception 'invalid_username'; end if;
      if char_length(coalesce(p_payload->>'p_display_name','')) > 128 then raise exception 'invalid_display_name'; end if;
      v_response := to_jsonb(public.start_game(
        v_telegram_id,
        coalesce(p_payload->>'p_site_username',''),
        coalesce(p_payload->>'p_display_name',''),
        coalesce(p_payload->>'p_country_code','TR'),
        coalesce(p_payload->>'p_country_name','Türkiye'),
        nullif(p_payload->>'p_referred_by','')
      ));
    when 'tap_coin' then
      if coalesce((p_payload->>'p_taps')::int, 0) not between 1 and 20 then raise exception 'invalid_tap_count'; end if;
      v_response := to_jsonb(public.tap_coin(v_telegram_id, (p_payload->>'p_taps')::int));
    when 'collect_income' then
      v_response := to_jsonb(public.collect_income(v_telegram_id, coalesce(p_request_id::text, '')));
    when 'marino_play_slot' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      v_response := to_jsonb(public.marino_play_slot(v_telegram_id, v_bet, coalesce(p_request_id::text,'')));
      perform public.marino_record_task_progress(v_player_id, 'slot_spin', 1);
      if (case when coalesce(v_response->>'win_amount','') ~ '^[0-9]+(\.[0-9]+)?$' then (v_response->>'win_amount')::numeric else 0 end) > 0 then
        perform public.marino_record_task_progress(v_player_id, 'slot_payline_win', 1);
      end if;
    when 'marino_play_mini_game' then
      if coalesce(p_payload->>'p_game_key','') !~ '^[a-z0-9_]{2,32}$' then raise exception 'invalid_game_key'; end if;
      v_response := to_jsonb(public.marino_play_mini_game(v_telegram_id, p_payload->>'p_game_key', coalesce(p_request_id::text,'')));
    when 'marino_buy_chips' then
      v_bet := coalesce((p_payload->>'p_chip_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_chip_amount'; end if;
      v_response := to_jsonb(public.marino_buy_chips(v_telegram_id, v_bet));
    when 'marino_get_referrals' then
      v_response := to_jsonb(public.marino_get_referrals(v_telegram_id));
    when 'marino_check_coupons' then
      v_response := to_jsonb(public.marino_check_coupons(v_telegram_id));
    when 'marino_get_my_notifications' then
      v_response := to_jsonb(public.marino_get_my_notifications(v_telegram_id));
    when 'marino_claim_daily_login' then
      v_response := to_jsonb(public.marino_claim_daily_login(v_telegram_id, coalesce(p_request_id::text,'')));
    when 'marino_upgrade_tap' then
      v_response := to_jsonb(public.marino_upgrade_tap(v_telegram_id, coalesce(p_request_id::text,'')));
    when 'marino_upgrade_capacity' then
      v_response := to_jsonb(public.marino_upgrade_capacity(v_telegram_id, coalesce(p_request_id::text,'')));
    when 'upgrade_building' then
      if coalesce(p_payload->>'p_building_key','') !~ '^[a-z0-9_]{2,64}$' then raise exception 'invalid_building_key'; end if;
      v_response := to_jsonb(public.upgrade_building(v_telegram_id, p_payload->>'p_building_key', coalesce(p_request_id::text,'')));
    when 'marino_claim_task' then
      if coalesce(p_payload->>'p_task_id','') !~ '^[a-z0-9_]{2,64}$' then raise exception 'invalid_task_id'; end if;
      if coalesce((p_payload->>'p_level_no')::int, 0) not between 1 and 10000 then raise exception 'invalid_level'; end if;
      v_response := to_jsonb(public.marino_claim_task(v_telegram_id, p_payload->>'p_task_id', (p_payload->>'p_level_no')::int, coalesce(p_request_id::text,'')));
    when 'request_reward' then
      if coalesce(p_payload->>'p_item_code','') !~ '^[a-z0-9_]{2,64}$' then raise exception 'invalid_item_code'; end if;
      v_response := to_jsonb(public.request_reward(v_telegram_id, p_payload->>'p_item_code', coalesce(p_request_id::text,'')));
    when 'marino_claim_referral' then
      if coalesce(p_payload->>'p_referred_id','') !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_referred_id'; end if;
      v_response := to_jsonb(public.marino_claim_referral(v_telegram_id, p_payload->>'p_referred_id', coalesce(p_request_id::text,'')));
    when 'marino_prestige' then
      v_response := to_jsonb(public.marino_prestige(v_telegram_id, coalesce(p_request_id::text,'')));
    when 'marino_get_leaderboard' then
      if coalesce(p_payload->>'p_scope','global') not in ('global','league') then raise exception 'invalid_scope'; end if;
      if coalesce(p_payload->>'p_country_code','TR') !~ '^[A-Z]{2}$' then raise exception 'invalid_country'; end if;
      v_response := to_jsonb(public.marino_get_leaderboard(
        coalesce(p_payload->>'p_scope','global'),
        coalesce(p_payload->>'p_country_code','TR'),
        coalesce(nullif(p_payload->>'p_min_lvl','')::int,0),
        coalesce(nullif(p_payload->>'p_max_lvl','')::int,999)
      ));
    when 'marino_play_roulette_v2' then
      if jsonb_typeof(p_payload->'p_bets') <> 'object'
        or (select count(*) from jsonb_object_keys(p_payload->'p_bets')) > 50
      then raise exception 'invalid_bets'; end if;
      v_response := to_jsonb(public.marino_play_roulette_v2(v_telegram_id, p_payload->'p_bets', coalesce(p_request_id::text,'')));
      perform public.marino_record_task_progress(v_player_id, 'roulette_spin', 1);
      if exists(select 1 from jsonb_object_keys(p_payload->'p_bets') k(key) where key ~ '^[0-9]+$')
         and exists(select 1 from jsonb_object_keys(p_payload->'p_bets') k(key) where key !~ '^[0-9]+$') then
        perform public.marino_record_task_progress(v_player_id, 'roulette_mix', 1);
      end if;
    when 'marino_bj_deal' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      v_response := to_jsonb(public.marino_bj_deal(v_telegram_id, v_bet));
      perform public.marino_record_task_progress(v_player_id, 'blackjack_hand', 1);
    when 'marino_bj_hit' then
      v_response := to_jsonb(public.marino_bj_hit(v_telegram_id));
    when 'marino_bj_stand' then
      v_response := to_jsonb(public.marino_bj_stand(v_telegram_id));
    when 'marino_play_horse_racing' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      if coalesce((p_payload->>'p_horse_id')::int, 0) not between 1 and 6 then raise exception 'invalid_horse'; end if;
      v_response := to_jsonb(public.marino_play_horse_racing(v_telegram_id, v_bet::int, (p_payload->>'p_horse_id')::int));
    when 'marino_play_poker' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      v_response := to_jsonb(public.marino_play_poker(v_telegram_id, v_bet::int));
    when 'marino_get_live_matches' then
      v_response := to_jsonb(public.marino_get_live_matches());
    when 'marino_place_sports_bet' then
      v_bet := coalesce((p_payload->>'p_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      if coalesce(p_payload->>'p_match_id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' then raise exception 'invalid_match_id'; end if;
      if coalesce(p_payload->>'p_selection','') !~ '^[A-Za-z0-9_ -]{1,32}$' then raise exception 'invalid_selection'; end if;
      v_response := to_jsonb(public.marino_place_sports_bet(v_telegram_id, (p_payload->>'p_match_id')::uuid, p_payload->>'p_selection', v_bet));
    else
      raise exception 'action_not_allowed' using errcode = '42501';
  end case;

  if p_request_id is not null then
    update public.marino_idempotency_keys set response = v_response
    where auth_user_id = v_auth_user and request_id = p_request_id;
  end if;
  return v_response;
exception when others then
  if p_request_id is not null then
    delete from public.marino_idempotency_keys
    where auth_user_id = v_auth_user and request_id = p_request_id and response is null;
  end if;
  raise;
end;
$$;


revoke all on function public.marino_secure_rpc(text,jsonb,uuid) from public, anon;
grant execute on function public.marino_secure_rpc(text,jsonb,uuid) to authenticated;

commit;
