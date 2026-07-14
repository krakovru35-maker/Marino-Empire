-- Forward-only qualification fix for pgcrypto functions hosted in `extensions`.
begin;

create or replace function public.marino_social_ensure_profile()
returns public.marino_social_profiles
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record;
  v_profile public.marino_social_profiles;
  v_display text;
  v_initial text;
  v_code text;
  v_identity_created timestamptz;
  v_attempt integer := 0;
begin
  select * into strict v_user from public.marino_social_require_user();
  select * into v_profile from public.marino_social_profiles where auth_user_id = v_user.auth_user_id;
  if found then return v_profile; end if;

  select nullif(btrim(display_name), ''), created_at into v_display, v_identity_created
  from public.marino_identity_links where auth_user_id = v_user.auth_user_id;
  v_initial := case when v_display is null then null else upper(substring(v_display from 1 for 1)) end;

  loop
    v_attempt := v_attempt + 1;
    if v_attempt > 32 then raise exception 'social_code_generation_failed'; end if;
    v_code := upper(substring(encode(extensions.gen_random_bytes(2), 'hex') from 1 for 3));
    begin
      insert into public.marino_social_profiles(auth_user_id, social_code, public_alias, created_at)
      values (v_user.auth_user_id, v_code, coalesce(v_initial || '***', 'Oyuncu') || ' #' || v_code, coalesce(v_identity_created, now()))
      returning * into v_profile;
      insert into public.marino_social_stats(auth_user_id) values (v_user.auth_user_id);
      return v_profile;
    exception when unique_violation then
      select * into v_profile from public.marino_social_profiles where auth_user_id = v_user.auth_user_id;
      if found then return v_profile; end if;
    end;
  end loop;
end $$;

create or replace function public.marino_chat_send(p_channel text, p_body text, p_recipient_code text default null)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record; v_profile public.marino_social_profiles; v_recipient uuid; v_filtered text; v_fingerprint text;
  v_minute integer; v_hour integer; v_strikes integer; v_mute interval; v_message public.marino_chat_messages;
begin
  select * into strict v_user from public.marino_social_require_user();
  v_profile := public.marino_social_ensure_profile();
  select * into v_profile from public.marino_social_profiles where auth_user_id=v_user.auth_user_id for update;
  if v_profile.permanent_chat_ban then raise exception 'chat_banned' using errcode='42501'; end if;
  if v_profile.muted_until > now() then raise exception 'chat_muted_until:%', v_profile.muted_until using errcode='42501'; end if;
  if v_profile.created_at > now() - interval '10 minutes' then raise exception 'new_account_read_only' using errcode='42501'; end if;
  if p_channel not in ('general','league','private') then raise exception 'invalid_channel'; end if;
  if p_channel='private' then
    if p_recipient_code !~ '^[A-F0-9]{3}$' then raise exception 'recipient_required'; end if;
    select auth_user_id into v_recipient from public.marino_social_profiles where social_code=p_recipient_code;
    if v_recipient is null or not public.marino_social_are_friends(v_user.auth_user_id,v_recipient) or public.marino_social_is_blocked(v_user.auth_user_id,v_recipient) then raise exception 'private_recipient_not_allowed' using errcode='42501'; end if;
  elsif p_recipient_code is not null then raise exception 'recipient_not_allowed'; end if;

  v_filtered := public.marino_chat_filter(p_body);
  v_fingerprint := encode(extensions.digest(lower(v_filtered),'sha256'),'hex');
  select count(*) filter(where created_at >= now()-interval '1 minute'), count(*) filter(where created_at >= now()-interval '1 hour')
    into v_minute,v_hour from public.marino_chat_messages where sender_auth_user_id=v_user.auth_user_id;
  if v_profile.last_message_at > now()-interval '2 seconds' or v_minute >= 20 or v_hour >= 200 or
    (select normalized_fingerprint=v_fingerprint from public.marino_chat_messages where sender_auth_user_id=v_user.auth_user_id order by created_at desc limit 1) is true then
    v_strikes := least(3, case when v_profile.updated_at < now()-interval '24 hours' then 1 else v_profile.spam_strikes+1 end);
    v_mute := case v_strikes when 1 then interval '10 minutes' when 2 then interval '1 hour' else interval '24 hours' end;
    update public.marino_social_profiles set spam_strikes=v_strikes, muted_until=now()+v_mute, updated_at=now() where auth_user_id=v_user.auth_user_id;
    return jsonb_build_object('ok',false,'error','rate_limited','retry_after_seconds',extract(epoch from v_mute)::integer);
  end if;

  insert into public.marino_chat_messages(sender_auth_user_id,channel_type,league_key,recipient_auth_user_id,filtered_body,normalized_fingerprint)
  values(v_user.auth_user_id,p_channel,case when p_channel='league' then v_user.league_key end,v_recipient,v_filtered,v_fingerprint)
  returning * into v_message;
  update public.marino_social_profiles set last_message_at=now(),updated_at=now() where auth_user_id=v_user.auth_user_id;
  return jsonb_build_object('ok',true,'message_id',v_message.id,'alias',v_profile.public_alias,'body',v_filtered,'channel',p_channel,'created_at',v_message.created_at);
end $$;

create or replace function public.marino_gift_send(p_recipient_code text, p_gift_key text, p_request_id uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record; v_sender public.marino_social_profiles; v_recipient public.marino_social_profiles; v_gift public.marino_gift_catalog;
  v_player public.marino_players; v_tx public.marino_gift_transactions; v_day_total integer; v_pair_total integer; v_body text;
begin
  if p_request_id is null then raise exception 'request_id_required'; end if;
  select * into strict v_user from public.marino_social_require_user();
  v_sender := public.marino_social_ensure_profile();
  select * into v_recipient from public.marino_social_profiles where social_code=p_recipient_code;
  if v_recipient.auth_user_id is null or v_recipient.auth_user_id=v_user.auth_user_id then raise exception 'invalid_recipient'; end if;
  if public.marino_social_is_blocked(v_user.auth_user_id,v_recipient.auth_user_id) then raise exception 'recipient_blocked' using errcode='42501'; end if;
  select * into v_gift from public.marino_gift_catalog where gift_key=p_gift_key and active;
  if v_gift.gift_key is null then raise exception 'gift_not_available'; end if;
  select * into v_tx from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and request_id=p_request_id;
  if found then return jsonb_build_object('ok',true,'idempotent',true,'transaction_id',v_tx.id); end if;
  select count(*),count(*) filter(where recipient_auth_user_id=v_recipient.auth_user_id) into v_day_total,v_pair_total
  from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and created_at >= date_trunc('day',now());
  if v_day_total >= 10 then raise exception 'daily_gift_limit'; end if;
  if v_pair_total >= 3 then raise exception 'recipient_daily_gift_limit'; end if;
  select * into strict v_player from public.marino_players where id=v_user.player_id for update;
  if coalesce(v_player.marino_coin,0) < v_gift.coin_price then raise exception 'insufficient_coin'; end if;
  update public.marino_players set marino_coin=marino_coin-v_gift.coin_price,updated_at=now() where id=v_player.id;
  insert into public.marino_gift_transactions(sender_auth_user_id,recipient_auth_user_id,gift_key,coin_price,prestige_points,request_id)
  values(v_user.auth_user_id,v_recipient.auth_user_id,v_gift.gift_key,v_gift.coin_price,v_gift.prestige_points,p_request_id) returning * into v_tx;
  insert into public.marino_social_stats(auth_user_id,gifts_received,prestige_points) values(v_recipient.auth_user_id,1,v_gift.prestige_points)
  on conflict(auth_user_id) do update set gifts_received=public.marino_social_stats.gifts_received+1,prestige_points=public.marino_social_stats.prestige_points+excluded.prestige_points,updated_at=now();
  v_body := v_sender.public_alias || ', ' || v_recipient.public_alias || ' oyuncusuna ' || lower(v_gift.display_name) || ' gönderdi ' || v_gift.emoji;
  insert into public.marino_chat_messages(sender_auth_user_id,channel_type,message_kind,filtered_body,normalized_fingerprint,gift_transaction_id)
  values(v_user.auth_user_id,'general','gift',v_body,encode(extensions.digest(v_tx.id::text,'sha256'),'hex'),v_tx.id);
  return jsonb_build_object('ok',true,'idempotent',false,'transaction_id',v_tx.id,'coin_spent',v_gift.coin_price,'coin_balance',v_player.marino_coin-v_gift.coin_price);
exception when unique_violation then
  select * into v_tx from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and request_id=p_request_id;
  if found then return jsonb_build_object('ok',true,'idempotent',true,'transaction_id',v_tx.id); end if;
  raise;
end $$;

revoke all on function public.marino_social_ensure_profile() from public, anon, authenticated;
revoke all on function public.marino_chat_send(text,text,text) from public, anon, authenticated;
revoke all on function public.marino_gift_send(text,text,uuid) from public, anon, authenticated;

commit;
