-- Claim Coin mining and reviewed FreeSpin/FreeBet request queue. PREPARE ONLY.
-- Apply in staging first; this migration does not grant rewards automatically.

begin;

create table if not exists public.marino_site_accounts (
  player_id bigint primary key references public.marino_players(id) on delete cascade,
  site_username text not null check (site_username ~ '^[A-Za-z0-9_.-]{3,32}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists marino_site_accounts_username_lc_uidx
  on public.marino_site_accounts ((lower(site_username)));

create table if not exists public.marino_claim_coin_wallets (
  player_id bigint primary key references public.marino_players(id) on delete cascade,
  claim_coin bigint not null default 0 check (claim_coin >= 0 and claim_coin <= 1000000000),
  lifetime_mined bigint not null default 0 check (lifetime_mined >= 0),
  mined_today integer not null default 0 check (mined_today >= 0 and mined_today <= 1000),
  mine_day date not null default current_date,
  last_mined_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.marino_reward_claim_requests (
  id uuid primary key default gen_random_uuid(),
  player_id bigint not null references public.marino_players(id) on delete restrict,
  site_username text not null check (site_username ~ '^[A-Za-z0-9_.-]{3,32}$'),
  reward_type text not null check (reward_type in ('free_spin','free_bet')),
  amount integer not null check (amount between 1 and 10),
  cost_claim_coin integer not null check (cost_claim_coin between 1 and 100000),
  status text not null default 'pending' check (status in ('pending','approved','rejected','fulfilled')),
  admin_note text not null default '' check (char_length(admin_note) <= 300),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete restrict
);

create index if not exists marino_reward_claim_requests_status_idx
  on public.marino_reward_claim_requests (status, created_at desc);
create index if not exists marino_reward_claim_requests_player_idx
  on public.marino_reward_claim_requests (player_id, created_at desc);

insert into public.marino_admin_permission_catalog(permission_key, description, critical)
values
  ('rewards.view','View reviewed FreeSpin/FreeBet reward claim requests',false),
  ('rewards.manage','Approve, reject or mark reviewed reward claim requests fulfilled',false)
on conflict(permission_key) do update
set description=excluded.description, critical=excluded.critical;

alter table public.marino_site_accounts enable row level security;
alter table public.marino_claim_coin_wallets enable row level security;
alter table public.marino_reward_claim_requests enable row level security;

drop policy if exists marino_site_accounts_deny_all on public.marino_site_accounts;
create policy marino_site_accounts_deny_all on public.marino_site_accounts for all using (false) with check (false);
drop policy if exists marino_claim_coin_wallets_deny_all on public.marino_claim_coin_wallets;
create policy marino_claim_coin_wallets_deny_all on public.marino_claim_coin_wallets for all using (false) with check (false);
drop policy if exists marino_reward_claim_requests_deny_all on public.marino_reward_claim_requests;
create policy marino_reward_claim_requests_deny_all on public.marino_reward_claim_requests for all using (false) with check (false);

revoke all on table public.marino_site_accounts from public, anon, authenticated;
revoke all on table public.marino_claim_coin_wallets from public, anon, authenticated;
revoke all on table public.marino_reward_claim_requests from public, anon, authenticated;

create or replace function public.marino_claim_cost(p_reward_type text)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case p_reward_type when 'free_spin' then 30 when 'free_bet' then 45 else null end
$$;

revoke all on function public.marino_claim_cost(text) from public, anon, authenticated;

create or replace function public.marino_claim_mining_rpc(
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
  v_auth uuid := auth.uid();
  v_player public.marino_players%rowtype;
  v_profile public.marino_site_accounts%rowtype;
  v_wallet public.marino_claim_coin_wallets%rowtype;
  v_response jsonb;
  v_username text;
  v_reward_type text;
  v_amount integer;
  v_limit integer;
  v_cost integer;
  v_mined integer;
  v_next timestamptz;
begin
  if v_auth is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_action is null or p_action !~ '^[a-z][a-z0-9_]{2,64}$' then raise exception 'invalid_action'; end if;
  if jsonb_typeof(coalesce(p_payload,'{}'::jsonb)) <> 'object' then raise exception 'invalid_payload'; end if;
  if p_payload ?| array['telegram_id','p_telegram_id','auth_user_id','player_id','role','admin_id'] then
    raise exception 'caller_identity_not_allowed' using errcode='42501';
  end if;

  select p.* into v_player
  from public.marino_identity_links l
  join public.marino_players p using (telegram_id)
  where l.auth_user_id = v_auth;
  if v_player.id is null then raise exception 'player_not_found'; end if;

  if p_action <> 'state' then
    if p_request_id is null then raise exception 'request_id_required'; end if;
    insert into public.marino_idempotency_keys(auth_user_id, request_id, action)
    values (v_auth, p_request_id, p_action)
    on conflict do nothing;
    if not found then
      select response into v_response from public.marino_idempotency_keys where auth_user_id=v_auth and request_id=p_request_id;
      return coalesce(v_response, jsonb_build_object('ok',false,'pending',true));
    end if;
  end if;

  insert into public.marino_claim_coin_wallets(player_id) values(v_player.id)
  on conflict(player_id) do nothing;

  if p_action = 'bind_site_username' then
    v_username := btrim(coalesce(p_payload->>'site_username',''));
    if v_username !~ '^[A-Za-z0-9_.-]{3,32}$' then raise exception 'invalid_site_username'; end if;
    if exists (
      select 1 from public.marino_site_accounts
      where lower(site_username)=lower(v_username) and player_id<>v_player.id
    ) then raise exception 'site_username_already_bound' using errcode='23505'; end if;
    if exists (
      select 1 from public.marino_reward_claim_requests
      where player_id=v_player.id and status='pending'
    ) and exists (
      select 1 from public.marino_site_accounts
      where player_id=v_player.id and lower(site_username)<>lower(v_username)
    ) then raise exception 'pending_request_blocks_username_change'; end if;
    insert into public.marino_site_accounts(player_id, site_username)
    values (v_player.id, v_username)
    on conflict(player_id) do update set site_username=excluded.site_username, updated_at=now();
  elsif p_action = 'mine_claim_coin' then
    select * into v_profile from public.marino_site_accounts where player_id=v_player.id;
    if v_profile.player_id is null then raise exception 'site_username_required'; end if;
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id for update;
    if v_wallet.mine_day <> current_date then
      update public.marino_claim_coin_wallets set mined_today=0, mine_day=current_date where player_id=v_player.id returning * into v_wallet;
    end if;
    if v_wallet.last_mined_at is not null and v_wallet.last_mined_at > now() - interval '20 minutes' then raise exception 'mine_cooldown_active'; end if;
    if v_wallet.mined_today >= 18 then raise exception 'daily_mining_cap_reached'; end if;
    v_mined := least(18 - v_wallet.mined_today, 1 + floor(random() * 3)::integer);
    update public.marino_claim_coin_wallets
    set claim_coin=claim_coin+v_mined, lifetime_mined=lifetime_mined+v_mined, mined_today=mined_today+v_mined,
        last_mined_at=now(), updated_at=now()
    where player_id=v_player.id
    returning * into v_wallet;
    v_response := jsonb_build_object('ok',true,'mined',v_mined,'message','+'||v_mined||' Claim Coin','wallet',to_jsonb(v_wallet)||jsonb_build_object('next_mine_at',v_wallet.last_mined_at + interval '20 minutes','daily_cap',18));
  elsif p_action = 'create_reward_claim' then
    select * into v_profile from public.marino_site_accounts where player_id=v_player.id;
    if v_profile.player_id is null then raise exception 'site_username_required'; end if;
    v_reward_type := coalesce(p_payload->>'reward_type','');
    if v_reward_type not in ('free_spin','free_bet') then raise exception 'invalid_reward_type'; end if;
    if p_payload ? 'amount' and (p_payload->>'amount') !~ '^[0-9]{1,2}$' then raise exception 'invalid_reward_amount'; end if;
    v_amount := coalesce((p_payload->>'amount')::integer, 1);
    if v_amount not between 1 and 10 then raise exception 'invalid_reward_amount'; end if;
    if (select count(*) from public.marino_reward_claim_requests where player_id=v_player.id and status='pending') >= 5 then
      raise exception 'too_many_pending_claims';
    end if;
    v_cost := public.marino_claim_cost(v_reward_type) * v_amount;
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id for update;
    if coalesce(v_wallet.claim_coin,0) < v_cost then raise exception 'insufficient_claim_coin'; end if;
    update public.marino_claim_coin_wallets
    set claim_coin=claim_coin-v_cost, updated_at=now()
    where player_id=v_player.id
    returning * into v_wallet;
    insert into public.marino_reward_claim_requests(player_id, site_username, reward_type, amount, cost_claim_coin)
    values (v_player.id, v_profile.site_username, v_reward_type, v_amount, v_cost);
  elsif p_action <> 'state' then
    raise exception 'claim_action_not_allowed' using errcode='42501';
  end if;

  if v_response is null then
    select * into v_profile from public.marino_site_accounts where player_id=v_player.id;
    select * into v_wallet from public.marino_claim_coin_wallets where player_id=v_player.id;
    v_next := case when v_wallet.last_mined_at is null then null else v_wallet.last_mined_at + interval '20 minutes' end;
    select jsonb_build_object(
      'ok',true,
      'profile', case when v_profile.player_id is null then null else jsonb_build_object('site_username',v_profile.site_username,'locked',true,'updated_at',v_profile.updated_at) end,
      'wallet', to_jsonb(v_wallet) || jsonb_build_object('next_mine_at',v_next,'daily_cap',18),
      'costs', jsonb_build_object('free_spin',30,'free_bet',45),
      'requests', coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc) filter (where r.id is not null),'[]'::jsonb),
      'server_time', now()
    ) into v_response
    from (
      select id,site_username,reward_type,amount,cost_claim_coin,status,created_at,resolved_at,admin_note
      from public.marino_reward_claim_requests
      where player_id=v_player.id
      order by created_at desc
      limit 10
    ) r;
  end if;

  if p_action <> 'state' then
    update public.marino_idempotency_keys set response=v_response where auth_user_id=v_auth and request_id=p_request_id;
  end if;
  return v_response;
exception when others then
  if p_action <> 'state' and p_request_id is not null then
    delete from public.marino_idempotency_keys where auth_user_id=v_auth and request_id=p_request_id and response is null;
  end if;
  raise;
end $$;

revoke all on function public.marino_claim_mining_rpc(text,jsonb,uuid) from public, anon;
grant execute on function public.marino_claim_mining_rpc(text,jsonb,uuid) to authenticated;

create or replace function public.marino_claim_admin_rpc(
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
  v_result jsonb;
  v_request uuid;
  v_status text;
  v_before jsonb;
  v_after jsonb;
  v_note text;
  v_limit integer;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_action is null or p_action !~ '^[a-z][a-z0-9_]{2,64}$' then raise exception 'invalid_action'; end if;
  if p_request_id is null or jsonb_typeof(coalesce(p_payload,'{}'::jsonb)) <> 'object' then raise exception 'invalid_admin_request'; end if;
  if p_payload ?| array['telegram_id','p_telegram_id','auth_user_id','player_id','role','admin_id','resolved_by'] then
    raise exception 'caller_identity_not_allowed' using errcode='42501';
  end if;

  if p_action = 'claims_list' then
    v_member := public.marino_admin_require('rewards.view', false);
    v_status := coalesce(p_payload->>'status','pending');
    if v_status not in ('pending','approved','rejected','fulfilled','all') then raise exception 'invalid_status'; end if;
    if p_payload ? 'limit' and (p_payload->>'limit') !~ '^[0-9]{1,3}$' then raise exception 'invalid_limit'; end if;
    v_limit := least(greatest(coalesce((p_payload->>'limit')::integer,100),1),200);
    select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb))
    into v_result
    from (
      select r.id,r.site_username,r.reward_type,r.amount,r.cost_claim_coin,r.status,r.created_at,r.resolved_at,r.admin_note,
             p.telegram_id,p.display_name,p.casino_level
      from public.marino_reward_claim_requests r
      join public.marino_players p on p.id=r.player_id
      where v_status='all' or r.status=v_status
      order by r.created_at desc
      limit v_limit
    ) x;
    return v_result;
  elsif p_action = 'claim_set_status' then
    v_member := public.marino_admin_require('rewards.manage', false);
    v_request := (p_payload->>'request_id')::uuid;
    v_status := coalesce(p_payload->>'status','');
    v_note := left(coalesce(p_payload->>'admin_note',''),300);
    if v_status not in ('approved','rejected','fulfilled') then raise exception 'invalid_status'; end if;
    select to_jsonb(r) into v_before from public.marino_reward_claim_requests r where id=v_request for update;
    if v_before is null then raise exception 'claim_request_not_found'; end if;
    if v_before->>'status' = 'rejected' or v_before->>'status' = 'fulfilled' then raise exception 'claim_request_closed'; end if;
    if v_status='fulfilled' and v_before->>'status' <> 'approved' then raise exception 'claim_must_be_approved_first'; end if;
    update public.marino_reward_claim_requests
      set status=v_status, admin_note=v_note, resolved_at=now(), resolved_by=v_member.auth_user_id
      where id=v_request
      returning to_jsonb(public.marino_reward_claim_requests.*) into v_after;
    insert into public.marino_admin_audit_details(admin_auth_user_id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result)
    values(v_member.auth_user_id,v_member.role,'rewards.manage','claim_set_status','reward_claim',v_request::text,v_before,v_after,'claim_panel_action',p_request_id,'succeeded');
    return jsonb_build_object('ok',true,'item',v_after);
  else
    raise exception 'claim_admin_action_not_allowed' using errcode='42501';
  end if;
end $$;

revoke all on function public.marino_claim_admin_rpc(text,jsonb,uuid) from public, anon;
grant execute on function public.marino_claim_admin_rpc(text,jsonb,uuid) to authenticated;

commit;
