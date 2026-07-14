-- Canonical in-game administration authority. Forward-only and data preserving.
begin;

create table public.marino_admin_memberships (
  auth_user_id uuid primary key references auth.users(id) on delete restrict,
  role text not null check (role in ('super_admin','admin')),
  is_owner boolean not null default false,
  active boolean not null default true,
  expires_at timestamptz,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_admin_action_at timestamptz,
  check (not is_owner or (role='super_admin' and active and expires_at is null))
);
create unique index marino_single_owner_idx on public.marino_admin_memberships ((is_owner)) where is_owner;

create table public.marino_admin_permission_catalog (
  permission_key text primary key check (permission_key ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'),
  admin_assignable boolean not null default true,
  description text not null default '' check (char_length(description)<=160)
);
create table public.marino_admin_membership_permissions (
  auth_user_id uuid not null references public.marino_admin_memberships(auth_user_id) on delete cascade,
  permission_key text not null references public.marino_admin_permission_catalog(permission_key) on delete restrict,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key(auth_user_id,permission_key)
);
create table public.marino_admin_action_policies (
  action text primary key check (action ~ '^[a-z][a-z0-9_]{2,63}$'),
  permission_key text not null references public.marino_admin_permission_catalog(permission_key),
  critical boolean not null default false,
  max_abs_delta bigint,
  check (max_abs_delta is null or max_abs_delta>0)
);
create table public.marino_admin_request_keys (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  request_id uuid not null,
  action text not null,
  response jsonb,
  created_at timestamptz not null default now(),
  primary key(auth_user_id,request_id)
);
create table public.marino_admin_audit_details (
  id bigint generated always as identity primary key,
  admin_auth_user_id uuid not null references auth.users(id) on delete restrict,
  admin_role text not null,
  permission_key text not null,
  action text not null,
  target_type text,
  target_id text,
  before_state jsonb,
  after_state jsonb,
  reason text,
  request_id uuid not null,
  request_metadata jsonb not null default '{}'::jsonb,
  result text not null check(result in ('succeeded','rejected','failed')),
  created_at timestamptz not null default now(),
  unique(admin_auth_user_id,request_id)
);
create table public.marino_game_settings (
  setting_key text primary key check(setting_key ~ '^[a-z][a-z0-9_.]{2,63}$'),
  setting_value jsonb not null,
  version integer not null default 1 check(version>0),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create table public.marino_feature_flags (
  flag_key text primary key check(flag_key ~ '^[a-z][a-z0-9_.]{2,63}$'),
  enabled boolean not null default false,
  config jsonb not null default '{}'::jsonb,
  version integer not null default 1 check(version>0),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.marino_admin_permission_catalog(permission_key,admin_assignable,description) values
('dashboard.view',true,'Yonetim ozetini goruntule'),('users.view',true,'Oyunculari goruntule'),
('users.edit',true,'Oyuncu notlarini duzenle'),('users.ban',true,'Oyuncuyu yasakla'),('users.mute',true,'Sohbeti sustur'),
('economy.view',true,'Ekonomiyi goruntule'),('economy.adjust',true,'Sinirli bakiye duzeltmesi'),
('content.view',true,'Icerigi goruntule'),('content.manage',true,'Icerik yonet'),
('events.view',true,'Etkinlikleri goruntule'),('events.manage',true,'Etkinlikleri yonet'),
('rewards.view',true,'Odulleri goruntule'),('rewards.manage',true,'Odulleri yonet'),
('tasks.manage',true,'Gorevleri yonet'),('casino.manage',true,'Casino ayarlarini yonet'),
('social.view',true,'Sosyal kuyrugu goruntule'),('social.moderate',true,'Sosyal moderasyon yap'),
('notifications.send',true,'Bildirim gonder'),('reports.view',true,'Raporlari goruntule'),
('settings.manage',true,'Oyun ayarlarini yonet'),('audit.view',true,'Denetim kayitlarini goruntule'),
('announcements.view',true,'Duyurulari goruntule'),('announcements.create',true,'Duyuru olustur'),
('announcements.publish',true,'Duyuru yayinla'),('announcements.stop',true,'Duyuru durdur'),
('announcements.delete',true,'Duyuru sil'),('admins.manage',false,'Yalniz sistem sahibi admin yonetir');

insert into public.marino_admin_action_policies(action,permission_key,critical,max_abs_delta) values
('dashboard_stats','dashboard.view',false,null),('users_search','users.view',false,null),
('user_detail','users.view',false,null),('user_adjust_economy','economy.adjust',true,10000000),
('user_set_ban','users.ban',true,null),('admins_list','admins.manage',false,null),
('admin_grant','admins.manage',true,null),('admin_update_permissions','admins.manage',true,null),
('admin_revoke','admins.manage',true,null),('audit_list','audit.view',false,null),
('settings_get','settings.manage',false,null),('settings_update','settings.manage',true,null);

-- Preserve existing trusted operators without promoting anybody to owner.
insert into public.marino_admin_memberships(auth_user_id,role,active,expires_at,granted_by,granted_at)
select auth_user_id,'admin',active,expires_at,granted_by,granted_at from public.marino_admin_roles
on conflict(auth_user_id) do nothing;
insert into public.marino_admin_memberships(auth_user_id,role,active,expires_at,granted_at)
select auth_user_id,'admin',active,expires_at,granted_at from public.content_admin_users
on conflict(auth_user_id) do nothing;
insert into public.marino_admin_membership_permissions(auth_user_id,permission_key)
select m.auth_user_id,p.permission_key from public.marino_admin_memberships m cross join public.marino_admin_permission_catalog p
where p.admin_assignable and exists(select 1 from public.marino_admin_roles r where r.auth_user_id=m.auth_user_id and r.role='security_admin')
on conflict do nothing;
insert into public.marino_admin_membership_permissions(auth_user_id,permission_key)
select r.auth_user_id,p.permission_key from public.marino_admin_roles r join public.marino_admin_permission_catalog p
on p.permission_key=any(case r.role when 'operator' then array['dashboard.view','users.view','content.view','social.view','social.moderate','reports.view','audit.view'] else array['dashboard.view','users.view','social.view'] end)
on conflict do nothing;
insert into public.marino_admin_membership_permissions(auth_user_id,permission_key)
select c.auth_user_id,p.permission_key from public.content_admin_users c join public.marino_admin_permission_catalog p
on p.permission_key=any(case when c.role in ('publisher','super_admin') then array['content.view','content.manage','reports.view'] else array['content.view'] end)
on conflict do nothing;

create or replace function public.marino_admin_guard_owner()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if tg_op='DELETE' and old.is_owner then raise exception 'owner_is_immutable' using errcode='42501'; end if;
  if tg_op='UPDATE' and old.is_owner and (not new.is_owner or new.role<>'super_admin' or not new.active or new.expires_at is not null or new.auth_user_id<>old.auth_user_id) then
    raise exception 'owner_is_immutable' using errcode='42501';
  end if;
  return case when tg_op='DELETE' then old else new end;
end $$;
create trigger marino_admin_owner_guard before update or delete on public.marino_admin_memberships for each row execute function public.marino_admin_guard_owner();

create or replace function public.marino_admin_audit_immutable()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$ begin raise exception 'audit_is_immutable' using errcode='42501'; end $$;
create trigger marino_admin_audit_immutable before update or delete on public.marino_admin_audit_details for each row execute function public.marino_admin_audit_immutable();

create or replace function public.marino_admin_has_permission(p_permission text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
 select exists(select 1 from public.marino_admin_memberships m where m.auth_user_id=auth.uid() and m.active and (m.expires_at is null or m.expires_at>now()) and
 (m.role='super_admin' or exists(select 1 from public.marino_admin_membership_permissions mp where mp.auth_user_id=m.auth_user_id and mp.permission_key=p_permission)))
$$;
create or replace function public.marino_admin_me()
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
 select coalesce((select jsonb_build_object('is_admin',true,'role',m.role,'is_owner',m.is_owner,'permissions',case when m.role='super_admin' then (select jsonb_agg(permission_key order by permission_key) from public.marino_admin_permission_catalog) else (select jsonb_agg(permission_key order by permission_key) from public.marino_admin_membership_permissions where auth_user_id=m.auth_user_id) end) from public.marino_admin_memberships m where m.auth_user_id=auth.uid() and m.active and (m.expires_at is null or m.expires_at>now())),jsonb_build_object('is_admin',false,'role',null,'is_owner',false,'permissions','[]'::jsonb))
$$;

-- One-time owner bootstrap: numeric Telegram identity must already be verified.
create or replace function public.marino_bootstrap_owner(p_owner_telegram_id text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_user uuid; v_existing uuid;
begin
 if p_owner_telegram_id !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_owner_telegram_id'; end if;
 select auth_user_id into v_user from public.marino_identity_links where telegram_id=p_owner_telegram_id and last_verified_at>now()-interval '24 hours';
 if v_user is null then raise exception 'verified_owner_identity_required' using errcode='42501'; end if;
 select auth_user_id into v_existing from public.marino_admin_memberships where is_owner for update;
 if v_existing is not null and v_existing<>v_user then raise exception 'owner_already_assigned' using errcode='42501'; end if;
 insert into public.marino_admin_memberships(auth_user_id,role,is_owner,active,expires_at) values(v_user,'super_admin',true,true,null)
 on conflict(auth_user_id) do update set role='super_admin',is_owner=true,active=true,expires_at=null,updated_at=now();
 return jsonb_build_object('ok',true,'owner_assigned',true);
end $$;

create or replace function public.content_admin_role()
returns text language sql stable security definer set search_path = pg_catalog, public as $$
 select case when public.marino_admin_has_permission('content.manage') then 'publisher' when public.marino_admin_has_permission('content.view') then 'editor' else '' end
$$;

-- Legacy tables remain private compatibility mirrors; canonical memberships are authoritative.
create or replace function public.marino_admin_sync_legacy(p_user uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_member public.marino_admin_memberships; v_legacy_role text; v_content_role text;
begin
 select * into v_member from public.marino_admin_memberships where auth_user_id=p_user;
 if v_member.auth_user_id is null then
  delete from public.marino_admin_roles where auth_user_id=p_user;
  delete from public.content_admin_users where auth_user_id=p_user;
  return;
 end if;
 v_legacy_role:=case when v_member.role='super_admin' or exists(select 1 from public.marino_admin_membership_permissions where auth_user_id=p_user and permission_key in ('users.ban','economy.adjust')) then 'security_admin'
  when exists(select 1 from public.marino_admin_membership_permissions where auth_user_id=p_user and permission_key in ('social.moderate','users.view')) then 'operator' else 'support' end;
 insert into public.marino_admin_roles(auth_user_id,role,active,granted_by,granted_at,expires_at)
 values(p_user,v_legacy_role,v_member.active,v_member.granted_by,v_member.granted_at,v_member.expires_at)
 on conflict(auth_user_id) do update set role=excluded.role,active=excluded.active,granted_by=excluded.granted_by,granted_at=excluded.granted_at,expires_at=excluded.expires_at;
 v_content_role:=case when v_member.role='super_admin' or exists(select 1 from public.marino_admin_membership_permissions where auth_user_id=p_user and permission_key='content.manage') then 'publisher'
  when exists(select 1 from public.marino_admin_membership_permissions where auth_user_id=p_user and permission_key='content.view') then 'editor' else 'viewer' end;
 insert into public.content_admin_users(auth_user_id,role,active,granted_by,granted_at,expires_at)
 values(p_user,v_content_role,v_member.active,v_member.granted_by,v_member.granted_at,v_member.expires_at)
 on conflict(auth_user_id) do update set role=excluded.role,active=excluded.active,granted_by=excluded.granted_by,granted_at=excluded.granted_at,expires_at=excluded.expires_at;
end $$;
create or replace function public.marino_admin_sync_legacy_trigger()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin perform public.marino_admin_sync_legacy(case when tg_op='DELETE' then old.auth_user_id else new.auth_user_id end); return case when tg_op='DELETE' then old else new end; end $$;
create trigger marino_admin_membership_legacy_sync after insert or update or delete on public.marino_admin_memberships for each row execute function public.marino_admin_sync_legacy_trigger();
create trigger marino_admin_permission_legacy_sync after insert or update or delete on public.marino_admin_membership_permissions for each row execute function public.marino_admin_sync_legacy_trigger();
do $$ declare v_user uuid; begin for v_user in select auth_user_id from public.marino_admin_memberships loop perform public.marino_admin_sync_legacy(v_user); end loop; end $$;

alter table public.marino_admin_memberships enable row level security;
alter table public.marino_admin_permission_catalog enable row level security;
alter table public.marino_admin_membership_permissions enable row level security;
alter table public.marino_admin_action_policies enable row level security;
alter table public.marino_admin_request_keys enable row level security;
alter table public.marino_admin_audit_details enable row level security;
alter table public.marino_game_settings enable row level security;
alter table public.marino_feature_flags enable row level security;
do $$ declare t text; begin
 foreach t in array array['marino_admin_memberships','marino_admin_permission_catalog','marino_admin_membership_permissions','marino_admin_action_policies','marino_admin_request_keys','marino_admin_audit_details','marino_game_settings','marino_feature_flags'] loop
  execute format('revoke all on table public.%I from public,anon,authenticated',t);
 end loop;
end $$;
revoke all on function public.marino_admin_guard_owner() from public,anon,authenticated;
revoke all on function public.marino_admin_audit_immutable() from public,anon,authenticated;
revoke all on function public.marino_admin_has_permission(text) from public,anon,authenticated;
revoke all on function public.marino_admin_me() from public,anon;
grant execute on function public.marino_admin_me() to authenticated;
revoke all on function public.marino_bootstrap_owner(text) from public,anon,authenticated;
grant execute on function public.marino_bootstrap_owner(text) to service_role;
revoke all on function public.content_admin_role() from public,anon,authenticated;
revoke all on function public.marino_admin_sync_legacy(uuid) from public,anon,authenticated;
revoke all on function public.marino_admin_sync_legacy_trigger() from public,anon,authenticated;

commit;
