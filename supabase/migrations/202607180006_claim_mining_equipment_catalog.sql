-- Claim Mining equipment, reviewed activity tasks and admin-managed reward prices.
-- Only non-financial, reviewed participation tasks are included.

begin;

create table if not exists public.marino_claim_reward_catalog (
  catalog_code text primary key check (catalog_code ~ '^[a-z][a-z0-9_]{2,40}$'),
  reward_type text not null check (reward_type in ('free_spin','free_bet')),
  display_name text not null check (char_length(display_name) between 3 and 60),
  amount integer not null check (amount between 1 and 10),
  cost_claim_coin integer not null check (cost_claim_coin between 1 and 100000),
  active boolean not null default true,
  sort_order integer not null default 0 check (sort_order between 0 and 1000),
  updated_at timestamptz not null default now()
);

create table if not exists public.marino_claim_equipment_catalog (
  item_key text primary key check (item_key ~ '^[a-z][a-z0-9_]{2,40}$'),
  item_name text not null check (char_length(item_name) between 3 and 60),
  description text not null check (char_length(description) between 3 and 180),
  icon text not null check (char_length(icon) between 1 and 8),
  cost_claim_coin integer not null check (cost_claim_coin between 1 and 100000),
  required_lifetime_mined integer not null check (required_lifetime_mined between 0 and 100000000),
  mine_bonus integer not null default 0 check (mine_bonus between 0 and 10),
  cooldown_reduction_minutes integer not null default 0 check (cooldown_reduction_minutes between 0 and 10),
  active boolean not null default true,
  sort_order integer not null default 0 check (sort_order between 0 and 1000)
);

create table if not exists public.marino_claim_player_equipment (
  player_id bigint not null references public.marino_players(id) on delete cascade,
  item_key text not null references public.marino_claim_equipment_catalog(item_key) on delete restrict,
  purchased_at timestamptz not null default now(),
  primary key(player_id,item_key)
);

create table if not exists public.marino_claim_activity_catalog (
  task_key text primary key check (task_key ~ '^[a-z][a-z0-9_]{2,50}$'),
  task_name text not null check (char_length(task_name) between 3 and 80),
  description text not null check (char_length(description) between 3 and 240),
  task_type text not null check (task_type in ('onboarding','daily','weekly','security','community')),
  reward_claim_coin integer not null check (reward_claim_coin between 1 and 1000),
  goal integer not null default 1 check (goal between 1 and 1000),
  verification_source text not null default 'reviewed_admin' check (verification_source in ('reviewed_admin','signed_webhook')),
  active boolean not null default true,
  sort_order integer not null default 0 check (sort_order between 0 and 1000)
);

create table if not exists public.marino_claim_activity_progress (
  player_id bigint not null references public.marino_players(id) on delete cascade,
  task_key text not null references public.marino_claim_activity_catalog(task_key) on delete restrict,
  progress integer not null default 0 check (progress between 0 and 1000),
  verified_at timestamptz,
  verified_by uuid references auth.users(id) on delete restrict,
  claimed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(player_id,task_key)
);

insert into public.marino_claim_reward_catalog(catalog_code,reward_type,display_name,amount,cost_claim_coin,active,sort_order)
values
  ('free_spin_1','free_spin','1 Free Spin',1,30,true,10),
  ('free_spin_3','free_spin','3 Free Spin',3,84,true,20),
  ('free_spin_5','free_spin','5 Free Spin',5,135,true,30),
  ('free_bet_1','free_bet','1 Free Bet',1,45,true,40),
  ('free_bet_3','free_bet','3 Free Bet',3,126,true,50)
on conflict(catalog_code) do nothing;

insert into public.marino_claim_equipment_catalog(item_key,item_name,description,icon,cost_claim_coin,required_lifetime_mined,mine_bonus,cooldown_reduction_minutes,active,sort_order)
values
  ('steel_pickaxe','Çelik Kazma','Her kazımda +1 CC potansiyeli açar.','⛏',40,60,1,0,true,10),
  ('deep_scanner','Derin Tarayıcı','Kazım bekleme süresini 2 dakika azaltır.','⌁',90,180,0,2,true,20),
  ('diamond_drill','Elmas Matkap','Her kazımda +2 CC potansiyeli açar.','◆',220,500,2,0,true,30),
  ('quantum_rig','Kuantum Sondajı','Her kazımda +3 CC ve 4 dakika hız kazandırır.','⚙',600,1200,3,4,true,40)
on conflict(item_key) do nothing;

insert into public.marino_claim_activity_catalog(task_key,task_name,description,task_type,reward_claim_coin,goal,verification_source,active,sort_order)
values
  ('agent_connection','Ajan Bağlantısı','Telegram botunu başlat ve hesabını güvenli biçimde eşleştir.','onboarding',3,1,'reviewed_admin',true,10),
  ('account_2fa','Kasayı Sağlama Al','Hesap güvenliğin için SMS 2FA özelliğini etkinleştir.','security',5,1,'reviewed_admin',true,20),
  ('daily_safe_checkin','Günün İlk Kontrolü','Günlük hesap ve güvenlik kontrolünü tamamla.','daily',1,1,'reviewed_admin',true,30),
  ('crypto_safety_lesson','Kripto Güvenlik Eğitimi','Kripto cüzdan güvenliği mini eğitimini tamamla.','security',2,1,'reviewed_admin',true,40),
  ('seven_day_checkin','7 Günlük İstikrar','Yedi gün boyunca günlük güvenli giriş kontrolünü tamamla.','weekly',10,7,'reviewed_admin',true,50),
  ('account_recovery_ready','Hesap Kurtarma Hazır','Kurtarma seçeneklerini doğrula ve destek kontrolünü tamamla.','security',15,1,'reviewed_admin',true,60),
  ('weekend_community','Hafta Sonu Topluluğu','Hafta sonu topluluk etkinliğinin üç gününe katıl.','community',20,3,'reviewed_admin',true,70)
on conflict(task_key) do nothing;

alter table public.marino_claim_reward_catalog enable row level security;
alter table public.marino_claim_equipment_catalog enable row level security;
alter table public.marino_claim_player_equipment enable row level security;
alter table public.marino_claim_activity_catalog enable row level security;
alter table public.marino_claim_activity_progress enable row level security;

do $$ declare t text; begin
  foreach t in array array['marino_claim_reward_catalog','marino_claim_equipment_catalog','marino_claim_player_equipment','marino_claim_activity_catalog','marino_claim_activity_progress'] loop
    execute format('drop policy if exists %I on public.%I',t||'_deny_all',t);
    execute format('create policy %I on public.%I for all using (false) with check (false)',t||'_deny_all',t);
    execute format('revoke all on table public.%I from public,anon,authenticated',t);
  end loop;
end $$;

create or replace function public.marino_claim_mining_rpc(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_auth uuid := auth.uid(); v_player public.marino_players%rowtype; v_profile public.marino_site_accounts%rowtype;
  v_wallet public.marino_claim_coin_wallets%rowtype; v_response jsonb; v_username text; v_item public.marino_claim_equipment_catalog%rowtype;
  v_reward public.marino_claim_reward_catalog%rowtype; v_task public.marino_claim_activity_catalog%rowtype;
  v_progress public.marino_claim_activity_progress%rowtype; v_mined integer; v_bonus integer; v_reduction integer;
  v_cap integer; v_cooldown integer; v_next timestamptz;
begin
  if v_auth is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_action is null or p_action !~ '^[a-z][a-z0-9_]{2,64}$' then raise exception 'invalid_action'; end if;
  if jsonb_typeof(coalesce(p_payload,'{}'::jsonb)) <> 'object' then raise exception 'invalid_payload'; end if;
  if p_payload ?| array['telegram_id','p_telegram_id','auth_user_id','player_id','role','admin_id'] then raise exception 'caller_identity_not_allowed' using errcode='42501'; end if;
  select p.* into v_player from public.marino_identity_links l join public.marino_players p using(telegram_id) where l.auth_user_id=v_auth;
  if v_player.id is null then raise exception 'player_not_found'; end if;
  if p_action <> 'state' then
    if p_request_id is null then raise exception 'request_id_required'; end if;
    insert into public.marino_idempotency_keys(auth_user_id,request_id,action) values(v_auth,p_request_id,p_action) on conflict do nothing;
    if not found then select response into v_response from public.marino_idempotency_keys where auth_user_id=v_auth and request_id=p_request_id; return coalesce(v_response,jsonb_build_object('ok',false,'pending',true)); end if;
  end if;
  insert into public.marino_claim_coin_wallets(player_id) values(v_player.id) on conflict(player_id) do nothing;

  if p_action='bind_site_username' then
    if exists(select 1 from public.marino_site_accounts where player_id=v_player.id) then raise exception 'site_username_admin_only' using errcode='42501'; end if;
    v_username:=btrim(coalesce(p_payload->>'site_username',''));
    if v_username !~ '^[A-Za-z0-9_.-]{3,32}$' then raise exception 'invalid_site_username'; end if;
    if exists(select 1 from public.marino_site_accounts where lower(site_username)=lower(v_username)) then raise exception 'site_username_already_bound' using errcode='23505'; end if;
    insert into public.marino_site_accounts(player_id,site_username) values(v_player.id,v_username);
  elsif p_action='mine_claim_coin' then
    select * into v_profile from public.marino_site_accounts where player_id=v_player.id;
    if v_profile.player_id is null then raise exception 'site_username_required'; end if;
    select coalesce(sum(c.mine_bonus),0),coalesce(sum(c.cooldown_reduction_minutes),0) into v_bonus,v_reduction
      from public.marino_claim_player_equipment e join public.marino_claim_equipment_catalog c using(item_key) where e.player_id=v_player.id;
    v_cap:=18+least(12,v_bonus*2); v_cooldown:=greatest(10,20-least(10,v_reduction));
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id for update;
    if v_wallet.mine_day<>current_date then update public.marino_claim_coin_wallets set mined_today=0,mine_day=current_date where player_id=v_player.id returning * into v_wallet; end if;
    if v_wallet.last_mined_at is not null and v_wallet.last_mined_at>now()-make_interval(mins=>v_cooldown) then raise exception 'mine_cooldown_active'; end if;
    if v_wallet.mined_today>=v_cap then raise exception 'daily_mining_cap_reached'; end if;
    v_mined:=least(v_cap-v_wallet.mined_today,1+floor(random()*3)::integer+v_bonus);
    update public.marino_claim_coin_wallets set claim_coin=claim_coin+v_mined,lifetime_mined=lifetime_mined+v_mined,mined_today=mined_today+v_mined,last_mined_at=now(),updated_at=now() where player_id=v_player.id returning * into v_wallet;
    v_response:=jsonb_build_object('ok',true,'mined',v_mined,'message','+'||v_mined||' Claim Coin','wallet',to_jsonb(v_wallet)||jsonb_build_object('next_mine_at',v_wallet.last_mined_at+make_interval(mins=>v_cooldown),'daily_cap',v_cap));
  elsif p_action='buy_mining_item' then
    if coalesce(p_payload->>'item_key','') !~ '^[a-z][a-z0-9_]{2,40}$' then raise exception 'invalid_item'; end if;
    select * into v_item from public.marino_claim_equipment_catalog where item_key=p_payload->>'item_key' and active for update;
    if v_item.item_key is null then raise exception 'item_not_found'; end if;
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id for update;
    if v_wallet.lifetime_mined<v_item.required_lifetime_mined then raise exception 'item_progress_locked'; end if;
    if exists(select 1 from public.marino_claim_player_equipment where player_id=v_player.id and item_key=v_item.item_key) then raise exception 'item_already_owned'; end if;
    if v_wallet.claim_coin<v_item.cost_claim_coin then raise exception 'insufficient_claim_coin'; end if;
    update public.marino_claim_coin_wallets set claim_coin=claim_coin-v_item.cost_claim_coin,updated_at=now() where player_id=v_player.id returning * into v_wallet;
    insert into public.marino_claim_player_equipment(player_id,item_key) values(v_player.id,v_item.item_key);
  elsif p_action='create_reward_claim' then
    select * into v_profile from public.marino_site_accounts where player_id=v_player.id;
    if v_profile.player_id is null then raise exception 'site_username_required'; end if;
    select * into v_reward from public.marino_claim_reward_catalog where catalog_code=p_payload->>'catalog_code' and active for update;
    if v_reward.catalog_code is null then raise exception 'reward_not_found'; end if;
    if (select count(*) from public.marino_reward_claim_requests where player_id=v_player.id and status='pending')>=5 then raise exception 'too_many_pending_claims'; end if;
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id for update;
    if v_wallet.claim_coin<v_reward.cost_claim_coin then raise exception 'insufficient_claim_coin'; end if;
    update public.marino_claim_coin_wallets set claim_coin=claim_coin-v_reward.cost_claim_coin,updated_at=now() where player_id=v_player.id returning * into v_wallet;
    insert into public.marino_reward_claim_requests(player_id,site_username,reward_type,amount,cost_claim_coin) values(v_player.id,v_profile.site_username,v_reward.reward_type,v_reward.amount,v_reward.cost_claim_coin);
  elsif p_action='claim_activity_reward' then
    select * into v_task from public.marino_claim_activity_catalog where task_key=p_payload->>'task_key' and active;
    if v_task.task_key is null then raise exception 'task_not_found'; end if;
    select * into v_progress from public.marino_claim_activity_progress where player_id=v_player.id and task_key=v_task.task_key for update;
    if v_progress.verified_at is null or v_progress.progress<v_task.goal then raise exception 'task_not_verified'; end if;
    if v_progress.claimed_at is not null then raise exception 'task_already_claimed'; end if;
    update public.marino_claim_activity_progress set claimed_at=now(),updated_at=now() where player_id=v_player.id and task_key=v_task.task_key;
    update public.marino_claim_coin_wallets set claim_coin=claim_coin+v_task.reward_claim_coin,updated_at=now() where player_id=v_player.id returning * into v_wallet;
  elsif p_action<>'state' then raise exception 'claim_action_not_allowed' using errcode='42501'; end if;

  if v_response is null then
    select * into v_profile from public.marino_site_accounts where player_id=v_player.id;
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id;
    select coalesce(sum(c.mine_bonus),0),coalesce(sum(c.cooldown_reduction_minutes),0) into v_bonus,v_reduction from public.marino_claim_player_equipment e join public.marino_claim_equipment_catalog c using(item_key) where e.player_id=v_player.id;
    v_cap:=18+least(12,v_bonus*2); v_cooldown:=greatest(10,20-least(10,v_reduction)); v_next:=case when v_wallet.last_mined_at is null then null else v_wallet.last_mined_at+make_interval(mins=>v_cooldown) end;
    v_response:=jsonb_build_object(
      'ok',true,'profile',case when v_profile.player_id is null then null else jsonb_build_object('site_username',v_profile.site_username,'locked',true,'updated_at',v_profile.updated_at) end,
      'wallet',to_jsonb(v_wallet)||jsonb_build_object('next_mine_at',v_next,'daily_cap',v_cap),
      'reward_catalog',(select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order),'[]'::jsonb) from public.marino_claim_reward_catalog c where c.active),
      'equipment_catalog',(select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('owned',e.item_key is not null) order by c.sort_order),'[]'::jsonb) from public.marino_claim_equipment_catalog c left join public.marino_claim_player_equipment e on e.item_key=c.item_key and e.player_id=v_player.id where c.active),
      'activity_tasks',(select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('progress',coalesce(p.progress,0),'verified',p.verified_at is not null,'claimed',p.claimed_at is not null) order by c.sort_order),'[]'::jsonb) from public.marino_claim_activity_catalog c left join public.marino_claim_activity_progress p on p.task_key=c.task_key and p.player_id=v_player.id where c.active),
      'requests',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb) from (select id,site_username,reward_type,amount,cost_claim_coin,status,created_at,resolved_at,admin_note from public.marino_reward_claim_requests where player_id=v_player.id order by created_at desc limit 10) r),'server_time',now());
  end if;
  if p_action<>'state' then update public.marino_idempotency_keys set response=v_response where auth_user_id=v_auth and request_id=p_request_id; end if;
  return v_response;
exception when others then
  if p_action<>'state' and p_request_id is not null then delete from public.marino_idempotency_keys where auth_user_id=v_auth and request_id=p_request_id and response is null; end if;
  raise;
end;
$$;

revoke all on function public.marino_claim_mining_rpc(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_claim_mining_rpc(text,jsonb,uuid) to authenticated;

create or replace function public.marino_claim_admin_rpc(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_member public.marino_admin_memberships; v_result jsonb; v_request uuid; v_status text; v_before jsonb; v_after jsonb; v_note text; v_limit integer; v_current text; v_new text; v_task public.marino_claim_activity_catalog%rowtype; v_player_id bigint; v_progress integer;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_action is null or p_action !~ '^[a-z][a-z0-9_]{2,64}$' or p_request_id is null or jsonb_typeof(coalesce(p_payload,'{}'::jsonb))<>'object' then raise exception 'invalid_admin_request'; end if;
  if p_payload ?| array['telegram_id','p_telegram_id','auth_user_id','player_id','role','admin_id','resolved_by'] then raise exception 'caller_identity_not_allowed' using errcode='42501'; end if;
  if p_action='claims_list' then
    v_member:=public.marino_admin_require('rewards.view',false); v_status:=coalesce(p_payload->>'status','pending');
    if v_status not in ('pending','approved','rejected','fulfilled','all') then raise exception 'invalid_status'; end if;
    if p_payload?'limit' and (p_payload->>'limit')!~'^[0-9]{1,3}$' then raise exception 'invalid_limit'; end if; v_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,100),1),200);
    select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)) into v_result from (select r.id,r.site_username,r.reward_type,r.amount,r.cost_claim_coin,r.status,r.created_at,r.resolved_at,r.admin_note,p.telegram_id,p.display_name,p.casino_level from public.marino_reward_claim_requests r join public.marino_players p on p.id=r.player_id where v_status='all' or r.status=v_status order by r.created_at desc limit v_limit)x; return v_result;
  elsif p_action='claim_set_status' then
    v_member:=public.marino_admin_require('rewards.manage',false); v_request:=(p_payload->>'request_id')::uuid; v_status:=coalesce(p_payload->>'status',''); v_note:=left(coalesce(p_payload->>'admin_note',''),300);
    if v_status not in ('approved','rejected','fulfilled') then raise exception 'invalid_status'; end if; select to_jsonb(r) into v_before from public.marino_reward_claim_requests r where id=v_request for update; if v_before is null then raise exception 'claim_request_not_found'; end if;
    if v_before->>'status' in ('rejected','fulfilled') then raise exception 'claim_request_closed'; end if; if v_status='fulfilled' and v_before->>'status'<>'approved' then raise exception 'claim_must_be_approved_first'; end if;
    update public.marino_reward_claim_requests set status=v_status,admin_note=v_note,resolved_at=now(),resolved_by=v_member.auth_user_id where id=v_request returning to_jsonb(public.marino_reward_claim_requests.*) into v_after;
  elsif p_action='catalog_list' then
    v_member:=public.marino_admin_require('rewards.view',false); return jsonb_build_object('ok',true,'rewards',(select jsonb_agg(to_jsonb(c) order by sort_order) from public.marino_claim_reward_catalog c),'tasks',(select jsonb_agg(to_jsonb(c) order by sort_order) from public.marino_claim_activity_catalog c));
  elsif p_action='reward_catalog_update' then
    v_member:=public.marino_admin_require('rewards.manage',false); if coalesce(p_payload->>'catalog_code','')!~'^[a-z][a-z0-9_]{2,40}$' or coalesce(p_payload->>'cost_claim_coin','')!~'^[0-9]{1,6}$' then raise exception 'invalid_catalog_update'; end if;
    select to_jsonb(c) into v_before from public.marino_claim_reward_catalog c where catalog_code=p_payload->>'catalog_code' for update; if v_before is null then raise exception 'catalog_not_found'; end if;
    update public.marino_claim_reward_catalog set cost_claim_coin=(p_payload->>'cost_claim_coin')::integer,active=coalesce((p_payload->>'active')::boolean,active),updated_at=now() where catalog_code=p_payload->>'catalog_code' returning to_jsonb(public.marino_claim_reward_catalog.*) into v_after;
  elsif p_action='site_account_update' then
    v_member:=public.marino_admin_require('rewards.manage',false); v_current:=btrim(coalesce(p_payload->>'current_site_username','')); v_new:=btrim(coalesce(p_payload->>'new_site_username',''));
    if v_current!~'^[A-Za-z0-9_.-]{3,32}$' or v_new!~'^[A-Za-z0-9_.-]{3,32}$' then raise exception 'invalid_site_username'; end if;
    select player_id,to_jsonb(a) into v_player_id,v_before from public.marino_site_accounts a where lower(site_username)=lower(v_current) for update; if v_player_id is null then raise exception 'site_account_not_found'; end if;
    if exists(select 1 from public.marino_site_accounts where lower(site_username)=lower(v_new) and player_id<>v_player_id) then raise exception 'site_username_already_bound'; end if;
    update public.marino_site_accounts set site_username=v_new,updated_at=now() where player_id=v_player_id returning to_jsonb(public.marino_site_accounts.*) into v_after;
    update public.marino_reward_claim_requests set site_username=v_new where player_id=v_player_id and status in ('pending','approved');
  elsif p_action='activity_task_verify' then
    v_member:=public.marino_admin_require('rewards.manage',false); v_current:=btrim(coalesce(p_payload->>'site_username','')); if v_current!~'^[A-Za-z0-9_.-]{3,32}$' then raise exception 'invalid_site_username'; end if;
    select player_id into v_player_id from public.marino_site_accounts where lower(site_username)=lower(v_current); if v_player_id is null then raise exception 'site_account_not_found'; end if;
    select * into v_task from public.marino_claim_activity_catalog where task_key=p_payload->>'task_key' and active; if v_task.task_key is null then raise exception 'task_not_found'; end if;
    if coalesce(p_payload->>'progress','')!~'^[0-9]{1,4}$' then raise exception 'invalid_progress'; end if; v_progress:=least((p_payload->>'progress')::integer,v_task.goal);
    insert into public.marino_claim_activity_progress(player_id,task_key,progress,verified_at,verified_by,updated_at) values(v_player_id,v_task.task_key,v_progress,case when v_progress>=v_task.goal then now() else null end,v_member.auth_user_id,now()) on conflict(player_id,task_key) do update set progress=excluded.progress,verified_at=excluded.verified_at,verified_by=excluded.verified_by,updated_at=now();
    v_after:=jsonb_build_object('site_username',v_current,'task_key',v_task.task_key,'progress',v_progress,'goal',v_task.goal);
  else raise exception 'claim_admin_action_not_allowed' using errcode='42501'; end if;
  insert into public.marino_admin_audit_details(admin_auth_user_id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result) values(v_member.auth_user_id,v_member.role,'rewards.manage',p_action,'claim_system',coalesce(v_request::text,v_current,p_payload->>'catalog_code',p_payload->>'task_key','unknown'),v_before,v_after,'claim_panel_action',p_request_id,'succeeded');
  return jsonb_build_object('ok',true,'item',v_after);
end;
$$;

revoke all on function public.marino_claim_admin_rpc(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_claim_admin_rpc(text,jsonb,uuid) to authenticated;

commit;
