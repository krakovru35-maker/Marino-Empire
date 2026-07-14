-- Permission-checked administration gateway and versioned operational configuration.
begin;

create table public.marino_admin_user_notes (
  id bigint generated always as identity primary key,
  target_auth_user_id uuid not null references auth.users(id) on delete restrict,
  note text not null check(char_length(note) between 3 and 500),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table public.marino_admin_sanctions (
  id bigint generated always as identity primary key,
  target_auth_user_id uuid not null references auth.users(id) on delete restrict,
  sanction_type text not null check(sanction_type in ('game_ban','chat_mute','chat_ban','social_lock')),
  active boolean not null default true,
  expires_at timestamptz,
  reason text not null check(char_length(reason) between 8 and 500),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id),
  revoked_at timestamptz
);
create index marino_admin_sanctions_target_idx on public.marino_admin_sanctions(target_auth_user_id,active);

create table public.marino_events (
  id uuid primary key default gen_random_uuid(), title text not null check(char_length(title) between 3 and 80),
  status text not null default 'draft' check(status in ('draft','scheduled','active','paused','ended','cancelled')),
  starts_at timestamptz, ends_at timestamptz, min_level integer check(min_level between 1 and 9999),
  max_level integer check(max_level between 1 and 9999), config jsonb not null default '{}'::jsonb,
  version integer not null default 1, created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(ends_at is null or starts_at is null or ends_at>starts_at), check(max_level is null or min_level is null or max_level>=min_level)
);
create table public.marino_task_definitions (
  task_key text primary key check(task_key ~ '^[a-z][a-z0-9_]{2,63}$'), title text not null check(char_length(title) between 3 and 80),
  task_type text not null check(task_type in ('daily','level','social','event')), active boolean not null default false,
  starts_at timestamptz, ends_at timestamptz, reward_config jsonb not null default '{}'::jsonb,
  version integer not null default 1, updated_by uuid not null references auth.users(id), updated_at timestamptz not null default now()
);
create table public.marino_casino_configs (
  game_key text primary key check(game_key ~ '^[a-z][a-z0-9_]{2,63}$'), active boolean not null default false,
  maintenance boolean not null default false, min_bet bigint not null check(min_bet>0), max_bet bigint not null check(max_bet>=min_bet),
  display_order integer not null default 0 check(display_order between 0 and 1000), config_version integer not null default 1,
  campaign_config jsonb not null default '{}'::jsonb, updated_by uuid not null references auth.users(id), updated_at timestamptz not null default now()
);
create table public.marino_in_game_notifications (
  id uuid primary key default gen_random_uuid(), title text not null check(char_length(title) between 1 and 80),
  message text not null check(char_length(message) between 1 and 500), status text not null default 'draft' check(status in ('draft','scheduled','active','ended','cancelled')),
  target_rules jsonb not null default '{"type":"all"}'::jsonb, starts_at timestamptz, ends_at timestamptz,
  created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create or replace function public.marino_admin_require(p_permission text,p_critical boolean default false)
returns public.marino_admin_memberships language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_member public.marino_admin_memberships;
begin
 select * into v_member from public.marino_admin_memberships where auth_user_id=auth.uid() and active and (expires_at is null or expires_at>now());
 if v_member.auth_user_id is null then raise exception 'admin_required' using errcode='42501'; end if;
 if v_member.role<>'super_admin' and not exists(select 1 from public.marino_admin_membership_permissions where auth_user_id=v_member.auth_user_id and permission_key=p_permission) then
   raise exception 'admin_permission_required' using errcode='42501';
 end if;
 if p_permission='admins.manage' and not v_member.is_owner then raise exception 'owner_required' using errcode='42501'; end if;
 if p_critical and not exists(select 1 from public.marino_identity_links where auth_user_id=v_member.auth_user_id and last_verified_at>now()-interval '5 minutes') then
   raise exception 'recent_telegram_session_required' using errcode='42501';
 end if;
 return v_member;
end $$;

create or replace function public.marino_admin_gateway(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_policy public.marino_admin_action_policies; v_member public.marino_admin_memberships; v_result jsonb; v_target uuid; v_tg text;
 v_reason text:=btrim(coalesce(p_payload->>'reason','')); v_before jsonb; v_after jsonb; v_coin bigint; v_chips bigint; v_ticket integer; v_prestige integer;
 v_coin_delta bigint; v_chips_delta bigint; v_ticket_delta integer; v_prestige_delta integer; v_permissions text[];
begin
 if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'request_id_required'; end if;
 if p_action !~ '^[a-z][a-z0-9_]{2,63}$' or p_payload ?| array['role','is_owner','auth_user_id','admin_auth_user_id','telegram_id'] then raise exception 'invalid_admin_request'; end if;
 select * into v_policy from public.marino_admin_action_policies where action=p_action;
 if v_policy.action is null then raise exception 'admin_action_not_allowed' using errcode='42501'; end if;
 v_member:=public.marino_admin_require(v_policy.permission_key,v_policy.critical);
 insert into public.marino_admin_request_keys(auth_user_id,request_id,action) values(v_member.auth_user_id,p_request_id,p_action) on conflict do nothing;
 if not found then select response into v_result from public.marino_admin_request_keys where auth_user_id=v_member.auth_user_id and request_id=p_request_id; return coalesce(v_result,jsonb_build_object('ok',false,'pending',true)); end if;

 if v_policy.critical and (char_length(v_reason)<8 or coalesce((p_payload->>'confirmed')::boolean,false) is not true) then raise exception 'critical_confirmation_required'; end if;
 case p_action
 when 'dashboard_stats' then
   select jsonb_build_object('ok',true,'users',(select count(*) from public.marino_identity_links),'daily_active',(select count(*) from public.marino_identity_links where last_verified_at>now()-interval '24 hours'),
    'coin_supply',(select coalesce(sum(marino_coin),0) from public.marino_players),'active_social',(select count(*) from public.marino_social_profiles where updated_at>now()-interval '15 minutes'),
    'gifts_24h',(select count(*) from public.marino_gift_transactions where created_at>now()-interval '24 hours'),'pending_rewards',(select count(*) from public.marino_reward_requests where status='pending'),
    'open_reports',(select count(*) from public.marino_chat_reports where status='open'),'active_events',(select count(*) from public.marino_events where status='active')) into v_result;
 when 'users_search' then
   select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)) into v_result from (
    select l.auth_user_id,l.display_name,p.telegram_username,p.casino_level,p.marino_coin,p.casino_chips,p.reward_token,p.prestige_points,p.is_banned,p.created_at,p.updated_at,sp.public_alias
    from public.marino_identity_links l join public.marino_players p using(telegram_id) left join public.marino_social_profiles sp on sp.auth_user_id=l.auth_user_id
    where coalesce(p_payload->>'query','')='' or l.display_name ilike '%'||left(p_payload->>'query',64)||'%' or sp.public_alias ilike '%'||left(p_payload->>'query',64)||'%'
    order by p.updated_at desc limit least(100,greatest(1,coalesce((p_payload->>'limit')::integer,25))) offset least(100000,greatest(0,coalesce((p_payload->>'offset')::integer,0)))
   ) x;
 when 'user_detail' then
   v_target:=(p_payload->>'target_auth_user_id')::uuid;
   select jsonb_build_object('ok',true,'user',to_jsonb(x)) into v_result from (select l.auth_user_id,l.display_name,p.*,sp.public_alias,sp.muted_until,sp.permanent_chat_ban from public.marino_identity_links l join public.marino_players p using(telegram_id) left join public.marino_social_profiles sp on sp.auth_user_id=l.auth_user_id where l.auth_user_id=v_target) x;
   if v_result is null then raise exception 'target_not_found'; end if;
 when 'user_adjust_economy' then
   v_target:=(p_payload->>'target_auth_user_id')::uuid; v_coin_delta:=coalesce((p_payload->>'coin_delta')::bigint,0); v_chips_delta:=coalesce((p_payload->>'chips_delta')::bigint,0); v_ticket_delta:=coalesce((p_payload->>'ticket_delta')::integer,0); v_prestige_delta:=coalesce((p_payload->>'prestige_delta')::integer,0);
   if v_coin_delta=0 and v_chips_delta=0 and v_ticket_delta=0 and v_prestige_delta=0 then raise exception 'nonzero_delta_required'; end if;
   if v_member.role<>'super_admin' and (abs(v_coin_delta)>10000000 or abs(v_chips_delta)>1000000 or abs(v_ticket_delta)>1000 or abs(v_prestige_delta)>10) then raise exception 'admin_adjustment_limit'; end if;
   select l.telegram_id into v_tg from public.marino_identity_links l where l.auth_user_id=v_target; if v_tg is null then raise exception 'target_not_found'; end if;
   select marino_coin,casino_chips,reward_token,prestige_points into v_coin,v_chips,v_ticket,v_prestige from public.marino_players where telegram_id=v_tg for update;
   v_before:=jsonb_build_object('coin',v_coin,'chips',v_chips,'ticket',v_ticket,'prestige',v_prestige);
   if v_coin+v_coin_delta<0 or v_chips+v_chips_delta<0 or v_ticket+v_ticket_delta<0 or v_prestige+v_prestige_delta<0 then raise exception 'negative_balance_not_allowed'; end if;
   update public.marino_players set marino_coin=v_coin+v_coin_delta,casino_chips=v_chips+v_chips_delta,reward_token=v_ticket+v_ticket_delta,prestige_points=v_prestige+v_prestige_delta,updated_at=now() where telegram_id=v_tg;
   v_after:=jsonb_build_object('coin',v_coin+v_coin_delta,'chips',v_chips+v_chips_delta,'ticket',v_ticket+v_ticket_delta,'prestige',v_prestige+v_prestige_delta); v_result:=jsonb_build_object('ok',true,'balances',v_after);
 when 'user_set_ban' then
   v_target:=(p_payload->>'target_auth_user_id')::uuid; select telegram_id into v_tg from public.marino_identity_links where auth_user_id=v_target; if v_tg is null then raise exception 'target_not_found'; end if;
   select jsonb_build_object('is_banned',is_banned) into v_before from public.marino_players where telegram_id=v_tg for update;
   update public.marino_players set is_banned=coalesce((p_payload->>'banned')::boolean,true),updated_at=now() where telegram_id=v_tg;
   v_after:=jsonb_build_object('is_banned',coalesce((p_payload->>'banned')::boolean,true)); v_result:=jsonb_build_object('ok',true,'state',v_after);
 when 'admins_list' then
   select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)) into v_result from (select m.auth_user_id,m.role,m.is_owner,m.active,m.expires_at,m.granted_at,l.display_name,l.telegram_username,coalesce((select jsonb_agg(permission_key order by permission_key) from public.marino_admin_membership_permissions where auth_user_id=m.auth_user_id),'[]'::jsonb) permissions from public.marino_admin_memberships m join public.marino_identity_links l using(auth_user_id) order by m.is_owner desc,m.granted_at) x;
 when 'admin_grant' then
   if (p_payload->>'target_telegram_id') !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_target'; end if; select auth_user_id into v_target from public.marino_identity_links where telegram_id=p_payload->>'target_telegram_id' and last_verified_at>now()-interval '24 hours'; if v_target is null then raise exception 'verified_identity_required'; end if;
   insert into public.marino_admin_memberships(auth_user_id,role,active,expires_at,granted_by) values(v_target,'admin',true,(p_payload->>'expires_at')::timestamptz,v_member.auth_user_id) on conflict(auth_user_id) do update set active=true,expires_at=excluded.expires_at,updated_at=now();
   v_permissions:=array(select jsonb_array_elements_text(coalesce(p_payload->'permissions','[]'::jsonb))); if exists(select 1 from unnest(v_permissions) k left join public.marino_admin_permission_catalog c on c.permission_key=k where c.permission_key is null or not c.admin_assignable) then raise exception 'invalid_admin_permission'; end if;
   insert into public.marino_admin_membership_permissions(auth_user_id,permission_key,granted_by) select v_target,unnest(v_permissions),v_member.auth_user_id on conflict do nothing; v_result:=jsonb_build_object('ok',true);
 when 'admin_update_permissions' then
   v_target:=(p_payload->>'target_auth_user_id')::uuid; if v_target=v_member.auth_user_id or exists(select 1 from public.marino_admin_memberships where auth_user_id=v_target and is_owner) then raise exception 'protected_admin'; end if;
   v_permissions:=array(select jsonb_array_elements_text(coalesce(p_payload->'permissions','[]'::jsonb))); if exists(select 1 from unnest(v_permissions) k left join public.marino_admin_permission_catalog c on c.permission_key=k where c.permission_key is null or not c.admin_assignable) then raise exception 'invalid_admin_permission'; end if;
   select jsonb_build_object('permissions',coalesce(jsonb_agg(permission_key),'[]'::jsonb)) into v_before from public.marino_admin_membership_permissions where auth_user_id=v_target; delete from public.marino_admin_membership_permissions where auth_user_id=v_target; insert into public.marino_admin_membership_permissions(auth_user_id,permission_key,granted_by) select v_target,unnest(v_permissions),v_member.auth_user_id; v_after:=jsonb_build_object('permissions',to_jsonb(v_permissions)); v_result:=jsonb_build_object('ok',true);
 when 'admin_revoke' then
   v_target:=(p_payload->>'target_auth_user_id')::uuid; if v_target=v_member.auth_user_id or exists(select 1 from public.marino_admin_memberships where auth_user_id=v_target and is_owner) then raise exception 'protected_admin'; end if; delete from public.marino_admin_memberships where auth_user_id=v_target; v_result:=jsonb_build_object('ok',true);
 when 'audit_list' then
   select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)) into v_result from (select id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result,created_at from public.marino_admin_audit_details order by id desc limit least(200,greatest(1,coalesce((p_payload->>'limit')::integer,50)))) x;
 when 'settings_get' then select jsonb_build_object('ok',true,'settings',coalesce(jsonb_object_agg(setting_key,setting_value),'{}'::jsonb),'flags',(select coalesce(jsonb_object_agg(flag_key,jsonb_build_object('enabled',enabled,'config',config,'version',version)),'{}'::jsonb) from public.marino_feature_flags)) into v_result from public.marino_game_settings;
 when 'settings_update' then
   if p_payload->>'setting_key' not in ('maintenance.enabled','maintenance.message','registration.enabled','default.locale','rate_limits.safe') then raise exception 'setting_not_allowed'; end if;
   select setting_value into v_before from public.marino_game_settings where setting_key=p_payload->>'setting_key'; insert into public.marino_game_settings(setting_key,setting_value,updated_by) values(p_payload->>'setting_key',p_payload->'value',v_member.auth_user_id) on conflict(setting_key) do update set setting_value=excluded.setting_value,version=marino_game_settings.version+1,updated_by=excluded.updated_by,updated_at=now(); v_after:=p_payload->'value'; v_result:=jsonb_build_object('ok',true);
 else raise exception 'admin_action_not_implemented'; end case;
 insert into public.marino_admin_audit_details(admin_auth_user_id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result)
 values(v_member.auth_user_id,v_member.role,v_policy.permission_key,p_action,case when v_target is null then null else 'auth_user' end,v_target::text,v_before,v_after,nullif(v_reason,''),p_request_id,'succeeded');
 update public.marino_admin_memberships set last_admin_action_at=now(),updated_at=now() where auth_user_id=v_member.auth_user_id;
 update public.marino_admin_request_keys set response=v_result where auth_user_id=v_member.auth_user_id and request_id=p_request_id; return v_result;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then raise exception 'invalid_payload_value';
end $$;

do $$ declare t text; begin foreach t in array array['marino_admin_user_notes','marino_admin_sanctions','marino_events','marino_task_definitions','marino_casino_configs','marino_in_game_notifications'] loop execute format('alter table public.%I enable row level security',t); execute format('revoke all on table public.%I from public,anon,authenticated',t); end loop; end $$;
revoke all on sequence public.marino_admin_user_notes_id_seq from public,anon,authenticated;
revoke all on sequence public.marino_admin_sanctions_id_seq from public,anon,authenticated;
revoke all on function public.marino_admin_require(text,boolean) from public,anon,authenticated;
revoke all on function public.marino_admin_gateway(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_admin_gateway(text,jsonb,uuid) to authenticated;

commit;
