-- Authenticated gameplay gateway. PREPARE ONLY.
-- It derives telegram_id from auth.uid(); caller-supplied identity fields are rejected.

begin;

create or replace function public._marino_cipher_hint()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with answer as (select public.marino_get_today_cipher() as word),
  letters as (
    select ch, ord
    from answer, unnest(string_to_array(word, null)) with ordinality as value(ch, ord)
  )
  select jsonb_build_object(
    'word_length', (select char_length(word) from answer),
    'morse', string_agg(case ch
      when 'A' then '.-' when 'B' then '-...' when 'C' then '-.-.' when 'D' then '-..'
      when 'E' then '.' when 'F' then '..-.' when 'G' then '--.' when 'H' then '....'
      when 'I' then '..' when 'J' then '.---' when 'K' then '-.-' when 'L' then '.-..'
      when 'M' then '--' when 'N' then '-.' when 'O' then '---' when 'P' then '.--.'
      when 'Q' then '--.-' when 'R' then '.-.' when 'S' then '...' when 'T' then '-'
      when 'U' then '..-' when 'V' then '...-' when 'W' then '.--' when 'X' then '-..-'
      when 'Y' then '-.--' when 'Z' then '--..' else '' end, '   ' order by ord)
  ) from letters
$$;

revoke all on function public._marino_cipher_hint() from public, anon, authenticated;

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
begin
  if v_auth_user is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  if p_action is null or p_action !~ '^[a-z][a-z0-9_]{2,63}$' then raise exception 'invalid_action'; end if;
  if jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' then raise exception 'invalid_payload'; end if;
  if p_payload ?| array['p_telegram_id','telegram_id','p_admin_id','auth_user_id','role'] then
    raise exception 'caller_identity_not_allowed' using errcode = '42501';
  end if;

  v_telegram_id := public.marino_current_telegram_id();
  if v_telegram_id is null then raise exception 'verified_telegram_session_required' using errcode = '28000'; end if;

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
    when 'marino_connect_wallet' then
      if coalesce(p_payload->>'p_ton_address','') !~ '^(EQ|UQ)[A-Za-z0-9_-]{46}$' then raise exception 'valid_signed_ton_address_required'; end if;
      v_response := public.marino_connect_wallet(v_telegram_id, p_payload->>'p_ton_address');
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
      if coalesce((p_payload->>'p_limit')::int, 50) not between 1 and 100 then raise exception 'invalid_limit'; end if;
      v_response := to_jsonb(public.marino_get_leaderboard(
        coalesce((p_payload->>'p_limit')::int, 50),
        nullif(p_payload->>'p_min_lvl','')::int,
        nullif(p_payload->>'p_max_lvl','')::int
      ));
    when 'marino_play_roulette_v2' then
      if jsonb_typeof(p_payload->'p_bets') <> 'object'
        or (select count(*) from jsonb_object_keys(p_payload->'p_bets')) > 50
      then raise exception 'invalid_bets'; end if;
      v_response := to_jsonb(public.marino_play_roulette_v2(v_telegram_id, p_payload->'p_bets', coalesce(p_request_id::text,'')));
    when 'marino_bj_deal' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      v_response := to_jsonb(public.marino_bj_deal(v_telegram_id, v_bet));
    when 'marino_bj_hit' then
      v_response := to_jsonb(public.marino_bj_hit(v_telegram_id));
    when 'marino_bj_stand' then
      v_response := to_jsonb(public.marino_bj_stand(v_telegram_id));
    when 'marino_play_horse_racing' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      if coalesce((p_payload->>'p_horse_id')::int, 0) not between 1 and 6 then raise exception 'invalid_horse'; end if;
      v_response := to_jsonb(public.marino_play_horse_racing(v_telegram_id, v_bet, (p_payload->>'p_horse_id')::int));
    when 'marino_play_poker' then
      v_bet := coalesce((p_payload->>'p_bet_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      v_response := to_jsonb(public.marino_play_poker(v_telegram_id, v_bet));
    when 'marino_get_live_matches' then
      v_response := to_jsonb(public.marino_get_live_matches());
    when 'marino_place_sports_bet' then
      v_bet := coalesce((p_payload->>'p_amount')::bigint, 0);
      if v_bet not between 1 and 1000000 then raise exception 'invalid_bet'; end if;
      if coalesce(p_payload->>'p_selection','') !~ '^[A-Za-z0-9_ -]{1,32}$' then raise exception 'invalid_selection'; end if;
      v_response := to_jsonb(public.marino_place_sports_bet(v_telegram_id, (p_payload->>'p_match_id')::bigint, p_payload->>'p_selection', v_bet));
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
end
$$;

revoke all on function public.marino_secure_rpc(text,jsonb,uuid) from public, anon;
grant execute on function public.marino_secure_rpc(text,jsonb,uuid) to authenticated;

commit;
