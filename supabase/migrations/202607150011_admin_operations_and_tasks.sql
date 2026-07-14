-- Functional event/task administration and a server-authoritative task catalogue.
begin;

alter table public.marino_task_definitions
  drop constraint if exists marino_task_definitions_task_type_check;
alter table public.marino_task_definitions
  add constraint marino_task_definitions_task_type_check
  check(task_type in ('daily','weekly','level','achievement','social','event'));

-- The legacy catalogue contains upper-case level keys while the reviewed gameplay
-- gateway accepts canonical lower-case action payloads. Canonicalize definitions,
-- historical claims and the compatibility JSON without deleting a claim.
delete from public.marino_player_tasks old_claim
using public.marino_player_tasks canonical_claim
where old_claim.player_id = canonical_claim.player_id
  and old_claim.task_key <> lower(old_claim.task_key)
  and canonical_claim.task_key = lower(old_claim.task_key);
update public.marino_player_tasks set task_key = lower(task_key) where task_key <> lower(task_key);
update public.marino_tasks set task_key = lower(task_key) where task_key <> lower(task_key);
update public.marino_players p
set completed_tasks = coalesce((
  select jsonb_agg(lower(value) order by ord)
  from jsonb_array_elements_text(coalesce(p.completed_tasks, '[]'::jsonb)) with ordinality as x(value, ord)
), '[]'::jsonb)
where exists (
  select 1 from jsonb_array_elements_text(coalesce(p.completed_tasks, '[]'::jsonb)) x(value)
  where value <> lower(value)
);

insert into public.marino_tasks(task_key,task_name,description,task_type,reward_coin,reward_token,reward_xp,required_level,sort_order,is_active)
values
  ('soc_tg','Telegram Grubuna Katıl','Topluluk bağlantısını aç ve görevi tamamla.','achievement',5000,0,10,1,10,true),
  ('soc_tw','X Hesabını Takip Et','Sosyal bağlantıyı aç ve görevi tamamla.','achievement',2500,0,10,1,20,true),
  ('daily_mini','Mini Oyun Oyna','Günlük bir mini oyun görevi.','daily',200,0,5,1,130,true)
on conflict(task_key) do nothing;

insert into public.marino_task_definitions(task_key,title,task_type,active,reward_config,version,updated_by)
select t.task_key,t.task_name,t.task_type,t.is_active,
       jsonb_build_object('coin',t.reward_coin,'token',t.reward_token,'xp',t.reward_xp,'required_level',t.required_level,'description',t.description,'sort_order',t.sort_order),
       1,(select auth_user_id from public.marino_admin_memberships where is_owner limit 1)
from public.marino_tasks t
on conflict(task_key) do update set
  title=excluded.title,task_type=excluded.task_type,active=excluded.active,reward_config=excluded.reward_config,
  version=public.marino_task_definitions.version+1,updated_by=excluded.updated_by,updated_at=now();

insert into public.marino_admin_action_policies(action,permission_key,critical) values
  ('events_list','events.view',false),('event_upsert','events.manage',true),('event_set_status','events.manage',true),
  ('tasks_list','tasks.manage',false),('task_upsert','tasks.manage',true)
on conflict(action) do update set permission_key=excluded.permission_key,critical=excluded.critical;

create or replace function public.marino_task_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare v_user uuid:=auth.uid(); v_telegram text; v_player bigint; v_completed jsonb; v_items jsonb;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select l.telegram_id,p.id into v_telegram,v_player
  from public.marino_identity_links l join public.marino_players p using(telegram_id)
  where l.auth_user_id=v_user;
  if v_player is null then raise exception 'player_not_found'; end if;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.sort_order,t.required_level,t.task_key),'[]'::jsonb)
  into v_items from (
    select task_key,task_name,description,task_type,reward_coin,reward_token,reward_xp,required_level,sort_order
    from public.marino_tasks where is_active
  ) t;
  select coalesce(jsonb_agg(task_key order by task_key),'[]'::jsonb) into v_completed
  from (
    select distinct lower(value) task_key
    from public.marino_players p, jsonb_array_elements_text(coalesce(p.completed_tasks,'[]'::jsonb)) x(value)
    where p.id=v_player
    union
    select lower(pt.task_key)
    from public.marino_player_tasks pt left join public.marino_tasks t on t.task_key=lower(pt.task_key)
    where pt.player_id=v_player and (coalesce(t.task_type,'achievement')<>'daily' or pt.claimed_at>=current_date)
  ) completed;
  return jsonb_build_object('ok',true,'items',v_items,'completed',v_completed,'server_time',now());
end $$;

create or replace function public.marino_claim_task(p_telegram_id text,p_task_id text,p_level_no integer default 1,p_request_id text default '')
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_player public.marino_players%rowtype; v_task public.marino_tasks%rowtype; v_reward bigint;
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
  return jsonb_build_object('state',jsonb_build_object('marino_coin',v_player.marino_coin,'reward_token',v_player.reward_token,
    'energy',v_player.energy,'max_energy',v_player.max_energy,'tap_power',v_player.tap_power,
    'passive_income_per_hour',v_player.passive_income_per_hour,'casino_level',v_player.casino_level,
    'reputation',v_player.reputation,'claimable_coin',v_player.claimable_coin,
    'offline_capacity_hours',v_player.offline_capacity_hours,'prestige_points',v_player.prestige_points),
    'completed_tasks',(public.marino_task_state()->'completed'),'message','Görev ödülü alındı: +'||v_reward||' coin');
end $$;

create or replace function public.marino_operations_admin_rpc(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_policy public.marino_admin_action_policies; v_member public.marino_admin_memberships; v_result jsonb;
 v_id uuid; v_key text; v_before jsonb; v_after jsonb; v_reason text:=btrim(coalesce(p_payload->>'reason',''));
 v_type text; v_status text; v_reward_coin bigint; v_reward_token integer; v_reward_xp bigint; v_level integer; v_sort integer;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_request_id is null or jsonb_typeof(coalesce(p_payload,'{}'::jsonb))<>'object' then raise exception 'invalid_admin_request'; end if;
  if p_payload ?| array['auth_user_id','telegram_id','role','is_owner','updated_by','created_by'] then raise exception 'caller_identity_not_allowed' using errcode='42501'; end if;
  select * into v_policy from public.marino_admin_action_policies where action=p_action and (action like 'event%' or action like 'task%');
  if v_policy.action is null then raise exception 'operations_action_not_allowed' using errcode='42501'; end if;
  v_member:=public.marino_admin_require(v_policy.permission_key,v_policy.critical);
  insert into public.marino_admin_request_keys(auth_user_id,request_id,action) values(v_member.auth_user_id,p_request_id,p_action) on conflict do nothing;
  if not found then select response into v_result from public.marino_admin_request_keys where auth_user_id=v_member.auth_user_id and request_id=p_request_id; return coalesce(v_result,jsonb_build_object('ok',false,'pending',true)); end if;
  if v_policy.critical and (char_length(v_reason)<8 or coalesce((p_payload->>'confirmed')::boolean,false) is not true) then raise exception 'critical_confirmation_required'; end if;

  if p_action='events_list' then
    select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(e) order by e.updated_at desc),'[]'::jsonb)) into v_result
    from (select id,title,status,starts_at,ends_at,min_level,max_level,config,version,updated_at from public.marino_events) e;
  elsif p_action='event_upsert' then
    if char_length(btrim(coalesce(p_payload->>'title',''))) not between 3 and 80 then raise exception 'invalid_event_title'; end if;
    if jsonb_typeof(coalesce(p_payload->'config','{}'::jsonb))<>'object' then raise exception 'invalid_event_config'; end if;
    if nullif(p_payload->>'starts_at','') is not null and nullif(p_payload->>'ends_at','') is not null and (p_payload->>'ends_at')::timestamptz<=(p_payload->>'starts_at')::timestamptz then raise exception 'invalid_event_schedule'; end if;
    v_id:=nullif(p_payload->>'event_id','')::uuid;
    if v_id is null then
      insert into public.marino_events(title,status,starts_at,ends_at,min_level,max_level,config,created_by,updated_by)
      values(btrim(p_payload->>'title'),'draft',nullif(p_payload->>'starts_at','')::timestamptz,nullif(p_payload->>'ends_at','')::timestamptz,
        nullif(p_payload->>'min_level','')::integer,nullif(p_payload->>'max_level','')::integer,coalesce(p_payload->'config','{}'::jsonb),v_member.auth_user_id,v_member.auth_user_id)
      returning id,to_jsonb(public.marino_events.*) into v_id,v_after;
    else
      select to_jsonb(e) into v_before from public.marino_events e where id=v_id for update; if v_before is null then raise exception 'event_not_found'; end if;
      update public.marino_events set title=btrim(p_payload->>'title'),starts_at=nullif(p_payload->>'starts_at','')::timestamptz,
        ends_at=nullif(p_payload->>'ends_at','')::timestamptz,min_level=nullif(p_payload->>'min_level','')::integer,
        max_level=nullif(p_payload->>'max_level','')::integer,config=coalesce(p_payload->'config','{}'::jsonb),
        version=version+1,updated_by=v_member.auth_user_id,updated_at=now() where id=v_id returning to_jsonb(public.marino_events.*) into v_after;
    end if;
    v_result:=jsonb_build_object('ok',true,'event_id',v_id);
  elsif p_action='event_set_status' then
    v_id:=(p_payload->>'event_id')::uuid; v_status:=p_payload->>'status';
    if v_status not in ('scheduled','active','paused','ended','cancelled') then raise exception 'invalid_event_status'; end if;
    select to_jsonb(e) into v_before from public.marino_events e where id=v_id for update; if v_before is null then raise exception 'event_not_found'; end if;
    update public.marino_events set status=v_status,version=version+1,updated_by=v_member.auth_user_id,updated_at=now() where id=v_id returning to_jsonb(public.marino_events.*) into v_after;
    v_result:=jsonb_build_object('ok',true,'event_id',v_id,'status',v_status);
  elsif p_action='tasks_list' then
    select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(t) order by t.sort_order,t.required_level,t.task_key),'[]'::jsonb)) into v_result
    from (select task_key,task_name,description,task_type,reward_coin,reward_token,reward_xp,required_level,sort_order,is_active from public.marino_tasks) t;
  elsif p_action='task_upsert' then
    v_key:=lower(btrim(coalesce(p_payload->>'task_key',''))); v_type:=p_payload->>'task_type';
    if v_key!~'^[a-z][a-z0-9_]{2,63}$' or char_length(btrim(coalesce(p_payload->>'task_name',''))) not between 3 and 80 then raise exception 'invalid_task_definition'; end if;
    if v_type not in ('daily','weekly','level','achievement','event') then raise exception 'invalid_task_type'; end if;
    v_reward_coin:=coalesce((p_payload->>'reward_coin')::bigint,0); v_reward_token:=coalesce((p_payload->>'reward_token')::integer,0);
    v_reward_xp:=coalesce((p_payload->>'reward_xp')::bigint,0); v_level:=coalesce((p_payload->>'required_level')::integer,1); v_sort:=coalesce((p_payload->>'sort_order')::integer,0);
    if v_reward_coin not between 0 and 10000000 or v_reward_token not between 0 and 10000 or v_reward_xp not between 0 and 1000000 or v_level not between 1 and 9999 or v_sort not between 0 and 100000 then raise exception 'invalid_task_limits'; end if;
    select to_jsonb(t) into v_before from public.marino_tasks t where task_key=v_key for update;
    insert into public.marino_tasks(task_key,task_name,description,task_type,reward_coin,reward_token,reward_xp,required_level,sort_order,is_active)
    values(v_key,btrim(p_payload->>'task_name'),left(coalesce(p_payload->>'description',''),500),v_type,v_reward_coin,v_reward_token,v_reward_xp,v_level,v_sort,coalesce((p_payload->>'is_active')::boolean,false))
    on conflict(task_key) do update set task_name=excluded.task_name,description=excluded.description,task_type=excluded.task_type,
      reward_coin=excluded.reward_coin,reward_token=excluded.reward_token,reward_xp=excluded.reward_xp,required_level=excluded.required_level,
      sort_order=excluded.sort_order,is_active=excluded.is_active returning to_jsonb(public.marino_tasks.*) into v_after;
    insert into public.marino_task_definitions(task_key,title,task_type,active,reward_config,updated_by)
    values(v_key,btrim(p_payload->>'task_name'),v_type,coalesce((p_payload->>'is_active')::boolean,false),
      jsonb_build_object('coin',v_reward_coin,'token',v_reward_token,'xp',v_reward_xp,'required_level',v_level,'description',left(coalesce(p_payload->>'description',''),500),'sort_order',v_sort),v_member.auth_user_id)
    on conflict(task_key) do update set title=excluded.title,task_type=excluded.task_type,active=excluded.active,reward_config=excluded.reward_config,
      version=public.marino_task_definitions.version+1,updated_by=excluded.updated_by,updated_at=now();
    v_after:=v_after||jsonb_build_object('managed',true); v_result:=jsonb_build_object('ok',true,'task_key',v_key);
  else raise exception 'operations_action_not_implemented'; end if;

  insert into public.marino_admin_audit_details(admin_auth_user_id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result)
  values(v_member.auth_user_id,v_member.role,v_policy.permission_key,p_action,case when p_action like 'event%' then 'event' else 'task' end,
    coalesce(v_id::text,v_key),v_before,v_after,nullif(v_reason,''),p_request_id,'succeeded');
  update public.marino_admin_request_keys set response=v_result where auth_user_id=v_member.auth_user_id and request_id=p_request_id;
  return v_result;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then raise exception 'invalid_payload_value';
end $$;

revoke all on function public.marino_task_state() from public,anon;
grant execute on function public.marino_task_state() to authenticated;
revoke all on function public.marino_claim_task(text,text,integer,text) from public,anon,authenticated;
revoke all on function public.marino_operations_admin_rpc(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_operations_admin_rpc(text,jsonb,uuid) to authenticated;

commit;
