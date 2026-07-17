-- Server-confirmed mining and casino bonus missions with visible progress.
begin;

insert into public.marino_tasks
  (task_key,task_name,description,task_type,reward_coin,reward_token,reward_xp,required_level,sort_order,is_active)
values
  ('claim_profile_link','Üyeliğini Bağla','Sitedeki kullanıcı adını Claim Mining hesabına güvenli biçimde bağla.','achievement',100,0,10,1,300,true),
  ('claim_mine_daily','Günlük Claim Madencisi','Bugün toplam 5 Claim Coin kaz.','daily',50,0,10,1,310,true),
  ('claim_mine_weekly','Haftalık Claim Ustası','Bu hafta toplam 30 Claim Coin kaz.','weekly',180,0,30,1,320,true),
  ('claim_request_first','İlk Bonus Talebi','Claim Coin ile ilk Free Spin veya Free Bet talebini oluştur.','achievement',200,0,20,1,330,true),
  ('bonus_slot_route','Slot Bonus Rotası','Marino Fortune üzerinde 10 server onaylı spin tamamla.','daily',40,0,8,1,340,true),
  ('bonus_roulette_route','Rulet Bonus Rotası','Rulet masasında 5 server onaylı tur tamamla.','daily',40,0,8,1,350,true),
  ('bonus_blackjack_route','Blackjack Bonus Rotası','Blackjack masasında 5 server onaylı el başlat.','daily',40,0,8,1,360,true)
on conflict(task_key) do update set
  task_name=excluded.task_name,description=excluded.description,task_type=excluded.task_type,
  reward_coin=excluded.reward_coin,reward_token=excluded.reward_token,reward_xp=excluded.reward_xp,
  required_level=excluded.required_level,sort_order=excluded.sort_order,is_active=excluded.is_active;

insert into public.marino_task_progress_rules(task_key,metric,goal)
values
  ('claim_profile_link','claim_profile_bound',1),
  ('claim_mine_daily','claim_coin_mined',5),
  ('claim_mine_weekly','claim_coin_mined',30),
  ('claim_request_first','claim_request_created',1),
  ('bonus_slot_route','slot_spin',10),
  ('bonus_roulette_route','roulette_spin',5),
  ('bonus_blackjack_route','blackjack_hand',5)
on conflict(task_key) do update set metric=excluded.metric,goal=excluded.goal;

create or replace function public.marino_progress_site_account_created()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  perform public.marino_record_task_progress(new.player_id,'claim_profile_bound',1);
  return new;
end
$$;

create or replace function public.marino_progress_claim_coin_mined()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_delta integer;
begin
  v_delta := least(1000,greatest(0,(new.lifetime_mined-old.lifetime_mined)::integer));
  if v_delta > 0 then
    perform public.marino_record_task_progress(new.player_id,'claim_coin_mined',v_delta);
  end if;
  return new;
end
$$;

create or replace function public.marino_progress_claim_request_created()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  perform public.marino_record_task_progress(new.player_id,'claim_request_created',1);
  return new;
end
$$;

revoke all on function public.marino_progress_site_account_created() from public,anon,authenticated;
revoke all on function public.marino_progress_claim_coin_mined() from public,anon,authenticated;
revoke all on function public.marino_progress_claim_request_created() from public,anon,authenticated;

drop trigger if exists marino_site_account_task_progress on public.marino_site_accounts;
create trigger marino_site_account_task_progress
after insert on public.marino_site_accounts
for each row execute function public.marino_progress_site_account_created();

drop trigger if exists marino_claim_coin_task_progress on public.marino_claim_coin_wallets;
create trigger marino_claim_coin_task_progress
after update of lifetime_mined on public.marino_claim_coin_wallets
for each row when (new.lifetime_mined > old.lifetime_mined)
execute function public.marino_progress_claim_coin_mined();

drop trigger if exists marino_claim_request_task_progress on public.marino_reward_claim_requests;
create trigger marino_claim_request_task_progress
after insert on public.marino_reward_claim_requests
for each row execute function public.marino_progress_claim_request_created();

-- Existing players keep only lifetime achievement credit. Daily and weekly progress
-- starts from future server-confirmed actions after this rollout.
insert into public.marino_player_task_progress(player_id,metric,period_key,progress_value,updated_at)
select player_id,'claim_profile_bound','all',1,now() from public.marino_site_accounts
on conflict(player_id,metric,period_key) do update
set progress_value=greatest(public.marino_player_task_progress.progress_value,excluded.progress_value),updated_at=now();

insert into public.marino_player_task_progress(player_id,metric,period_key,progress_value,updated_at)
select player_id,'claim_coin_mined','all',least(lifetime_mined,1000000)::integer,now()
from public.marino_claim_coin_wallets where lifetime_mined>0
on conflict(player_id,metric,period_key) do update
set progress_value=greatest(public.marino_player_task_progress.progress_value,excluded.progress_value),updated_at=now();

insert into public.marino_player_task_progress(player_id,metric,period_key,progress_value,updated_at)
select player_id,'claim_request_created','all',least(count(*),1000000)::integer,now()
from public.marino_reward_claim_requests group by player_id
on conflict(player_id,metric,period_key) do update
set progress_value=greatest(public.marino_player_task_progress.progress_value,excluded.progress_value),updated_at=now();

create or replace function public.marino_task_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid:=auth.uid();
  v_player bigint;
  v_completed jsonb;
  v_items jsonb;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select p.id into v_player
  from public.marino_identity_links l join public.marino_players p using(telegram_id)
  where l.auth_user_id=v_user;
  if v_player is null then raise exception 'player_not_found'; end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.sort_order,x.required_level,x.task_key),'[]'::jsonb)
  into v_items
  from (
    select t.task_key,t.task_name,t.description,t.task_type,t.reward_coin,t.reward_token,t.reward_xp,
      t.required_level,t.sort_order,coalesce(r.goal,0) goal,coalesce(p.progress_value,0) progress
    from public.marino_tasks t
    left join public.marino_task_progress_rules r on r.task_key=t.task_key
    left join public.marino_player_task_progress p
      on p.player_id=v_player and p.metric=r.metric and p.period_key=public.marino_task_period_key(t.task_type)
    where t.is_active
  ) x;

  select coalesce(jsonb_agg(task_key order by task_key),'[]'::jsonb) into v_completed
  from (
    select distinct lower(value) task_key
    from public.marino_players p,jsonb_array_elements_text(coalesce(p.completed_tasks,'[]'::jsonb)) x(value)
    where p.id=v_player
    union
    select lower(pt.task_key)
    from public.marino_player_tasks pt left join public.marino_tasks t on t.task_key=lower(pt.task_key)
    where pt.player_id=v_player and (
      coalesce(t.task_type,'achievement') not in ('daily','weekly')
      or (t.task_type='daily' and pt.claimed_at>=current_date)
      or (t.task_type='weekly' and pt.claimed_at>=date_trunc('week',current_date)::date)
    )
  ) completed;
  return jsonb_build_object('ok',true,'items',v_items,'completed',v_completed,'server_time',now());
end
$$;

create or replace function public.marino_claim_task(
  p_telegram_id text,
  p_task_id text,
  p_level_no integer default 1,
  p_request_id text default ''
)
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
  v_period_start date;
  v_progress integer:=0;
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
    v_period:=public.marino_task_period_key(v_task.task_type);
    select progress_value into v_progress from public.marino_player_task_progress
    where player_id=v_player.id and metric=v_rule.metric and period_key=v_period;
    if coalesce(v_progress,0)<v_rule.goal then raise exception 'Görev henüz tamamlanmadı.'; end if;
  end if;

  if v_task.task_type in ('daily','weekly') then
    v_period_start:=case when v_task.task_type='daily' then current_date else date_trunc('week',current_date)::date end;
    if exists(select 1 from public.marino_player_tasks where player_id=v_player.id and task_key=p_task_id and claimed_at>=v_period_start) then
      raise exception 'Bu dönem görevi zaten tamamlandı.';
    end if;
    delete from public.marino_player_tasks where player_id=v_player.id and task_key=p_task_id;
  elsif exists(select 1 from public.marino_player_tasks where player_id=v_player.id and task_key=p_task_id) then
    raise exception 'Bu görevi zaten tamamladın.';
  end if;

  v_reward:=v_task.reward_coin;
  insert into public.marino_player_tasks(player_id,task_key) values(v_player.id,p_task_id);
  update public.marino_players
  set marino_coin=marino_coin+v_task.reward_coin,reward_token=reward_token+v_task.reward_token,
      reputation=reputation+v_task.reward_xp,updated_at=now()
  where id=v_player.id returning * into v_player;
  return jsonb_build_object('ok',true,'state',jsonb_build_object(
    'marino_coin',v_player.marino_coin,'reward_token',v_player.reward_token,
    'energy',v_player.energy,'max_energy',v_player.max_energy,'tap_power',v_player.tap_power,
    'passive_income_per_hour',v_player.passive_income_per_hour,'casino_level',v_player.casino_level,
    'reputation',v_player.reputation,'claimable_coin',v_player.claimable_coin,
    'offline_capacity_hours',v_player.offline_capacity_hours,'prestige_points',v_player.prestige_points),
    'completed_tasks',(public.marino_task_state()->'completed'),'message','Görev ödülü alındı: +'||v_reward||' coin');
end
$$;

revoke all on function public.marino_task_state() from public,anon;
grant execute on function public.marino_task_state() to authenticated;
revoke all on function public.marino_claim_task(text,text,integer,text) from public,anon,authenticated;

commit;
