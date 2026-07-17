-- Activate the remaining in-game admin modules through an authenticated,
-- permission-checked gateway. No player economy values are changed here.
begin;

insert into public.marino_admin_action_policies(action, permission_key, critical)
values
  ('settings_update', 'settings.manage', false),
  ('casino_config_upsert', 'casino.manage', false),
  ('social_penalty_release', 'social.moderate', false),
  ('notification_broadcast_prepare', 'notifications.send', false)
on conflict(action) do update
set permission_key = excluded.permission_key,
    critical = excluded.critical;

insert into public.marino_game_settings(setting_key, setting_value)
values
  ('maintenance.enabled', 'false'::jsonb),
  ('maintenance.message', '""'::jsonb),
  ('registration.enabled', 'true'::jsonb),
  ('default.locale', '"tr"'::jsonb),
  ('rate_limits.safe', 'true'::jsonb)
on conflict(setting_key) do nothing;

with owner_account as (
  select auth_user_id
  from public.marino_admin_memberships
  where is_owner and active
  order by granted_at
  limit 1
), defaults(game_key, min_bet, max_bet, display_order) as (
  values
    ('slot', 10::bigint, 1000::bigint, 10),
    ('roulette', 10::bigint, 5000::bigint, 20),
    ('blackjack', 20::bigint, 5000::bigint, 30),
    ('poker', 50::bigint, 10000::bigint, 40),
    ('horse', 10::bigint, 5000::bigint, 50),
    ('sports', 10::bigint, 10000::bigint, 60)
)
insert into public.marino_casino_configs
  (game_key, active, maintenance, min_bet, max_bet, display_order, updated_by)
select d.game_key, true, false, d.min_bet, d.max_bet, d.display_order, o.auth_user_id
from defaults d cross join owner_account o
on conflict(game_key) do nothing;

create or replace function public.marino_admin_modules_rpc(
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_member public.marino_admin_memberships;
  v_permission text;
  v_result jsonb;
  v_before jsonb;
  v_after jsonb;
  v_target text;
  v_mutating boolean;
  v_game_key text;
  v_social_code text;
  v_min_bet bigint;
  v_max_bet bigint;
  v_order integer;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'request_id_required'; end if;
  if p_action !~ '^[a-z][a-z0-9_]{2,63}$'
     or coalesce(p_payload, '{}'::jsonb) ?| array['role','is_owner','auth_user_id','admin_auth_user_id','telegram_id','player_id']
  then raise exception 'invalid_admin_request'; end if;

  v_permission := case
    when p_action like 'casino_%' then 'casino.manage'
    when p_action = 'social_penalties_list' then 'social.view'
    when p_action = 'social_penalty_release' then 'social.moderate'
    when p_action = 'notification_broadcast_prepare' then 'notifications.send'
    else null
  end;
  if v_permission is null then raise exception 'admin_action_not_allowed' using errcode='42501'; end if;
  v_member := public.marino_admin_require(v_permission, false);
  v_mutating := p_action in ('casino_config_upsert','social_penalty_release');

  if v_mutating then
    insert into public.marino_admin_request_keys(auth_user_id, request_id, action)
    values(v_member.auth_user_id, p_request_id, p_action)
    on conflict do nothing;
    if not found then
      select response into v_result
      from public.marino_admin_request_keys
      where auth_user_id=v_member.auth_user_id and request_id=p_request_id;
      return coalesce(v_result, jsonb_build_object('ok',false,'pending',true));
    end if;
  end if;

  case p_action
    when 'casino_configs_list' then
      select jsonb_build_object(
        'ok', true,
        'items', coalesce(jsonb_agg(to_jsonb(c) order by c.display_order, c.game_key), '[]'::jsonb)
      ) into v_result
      from public.marino_casino_configs c;

    when 'casino_config_upsert' then
      v_game_key := btrim(coalesce(p_payload->>'game_key',''));
      v_min_bet := coalesce((p_payload->>'min_bet')::bigint, 0);
      v_max_bet := coalesce((p_payload->>'max_bet')::bigint, 0);
      v_order := coalesce((p_payload->>'display_order')::integer, 0);
      if v_game_key not in ('slot','roulette','blackjack','poker','horse','sports')
         or v_min_bet < 1 or v_min_bet > 1000000
         or v_max_bet < v_min_bet or v_max_bet > 100000000
         or v_order < 0 or v_order > 1000
      then raise exception 'invalid_casino_config'; end if;
      select to_jsonb(c) into v_before from public.marino_casino_configs c where c.game_key=v_game_key for update;
      insert into public.marino_casino_configs
        (game_key, active, maintenance, min_bet, max_bet, display_order, updated_by)
      values
        (v_game_key, coalesce((p_payload->>'active')::boolean,true), coalesce((p_payload->>'maintenance')::boolean,false),
         v_min_bet, v_max_bet, v_order, v_member.auth_user_id)
      on conflict(game_key) do update set
        active=excluded.active, maintenance=excluded.maintenance, min_bet=excluded.min_bet,
        max_bet=excluded.max_bet, display_order=excluded.display_order,
        config_version=public.marino_casino_configs.config_version+1,
        updated_by=excluded.updated_by, updated_at=now();
      select to_jsonb(c) into v_after from public.marino_casino_configs c where c.game_key=v_game_key;
      v_target := v_game_key;
      v_result := jsonb_build_object('ok',true,'config',v_after);

    when 'social_penalties_list' then
      select jsonb_build_object(
        'ok', true,
        'items', coalesce(jsonb_agg(to_jsonb(x) order by x.updated_at desc), '[]'::jsonb)
      ) into v_result
      from (
        select social_code, public_alias, muted_until, permanent_chat_ban, spam_strikes, updated_at
        from public.marino_social_profiles
        where muted_until > now() or permanent_chat_ban or spam_strikes > 0
        order by updated_at desc
        limit least(200, greatest(1, coalesce((p_payload->>'limit')::integer,100)))
      ) x;

    when 'social_penalty_release' then
      v_social_code := upper(btrim(coalesce(p_payload->>'social_code','')));
      if v_social_code !~ '^[A-F0-9]{3}$' then raise exception 'invalid_social_code'; end if;
      select jsonb_build_object('muted_until',muted_until,'permanent_chat_ban',permanent_chat_ban,'spam_strikes',spam_strikes)
      into v_before from public.marino_social_profiles where social_code=v_social_code for update;
      if v_before is null then raise exception 'social_profile_not_found'; end if;
      update public.marino_social_profiles
      set muted_until=null, permanent_chat_ban=false, spam_strikes=0, updated_at=now()
      where social_code=v_social_code;
      v_after := jsonb_build_object('muted_until',null,'permanent_chat_ban',false,'spam_strikes',0);
      v_target := v_social_code;
      v_result := jsonb_build_object('ok',true);

    when 'notification_broadcast_prepare' then
      select jsonb_build_object('ok',true,'recipients',count(*)) into v_result
      from public.marino_players
      where telegram_id ~ '^[1-9][0-9]{2,32}$';

    else raise exception 'admin_action_not_implemented';
  end case;

  if v_mutating then
    insert into public.marino_admin_audit_details
      (admin_auth_user_id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result)
    values
      (v_member.auth_user_id,v_member.role,v_permission,p_action,
       case when v_target is null then null else 'admin_module' end,v_target,v_before,v_after,
       'admin_panel_quick_action',p_request_id,'succeeded');
    update public.marino_admin_request_keys set response=v_result
    where auth_user_id=v_member.auth_user_id and request_id=p_request_id;
  end if;
  return v_result;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_payload_value';
end
$$;

revoke all on function public.marino_admin_modules_rpc(text,jsonb,uuid) from public, anon;
grant execute on function public.marino_admin_modules_rpc(text,jsonb,uuid) to authenticated;

commit;
