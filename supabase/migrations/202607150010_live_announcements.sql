-- Targeted live announcements with sanitized realtime invalidation signals.
begin;

create table public.marino_announcements (
 id uuid primary key default gen_random_uuid(), title text not null check(char_length(title) between 1 and 80),
 message text not null check(char_length(message) between 1 and 500), icon text not null default '📢' check(char_length(icon) between 1 and 16),
 announcement_type text not null check(announcement_type in ('general','info','event','reward','update','maintenance','emergency','campaign','system')),
 priority text not null default 'normal' check(priority in ('low','normal','high','critical')),
 visual_template text not null default 'blue' check(visual_template in ('blue','gold','green','red','neutral')),
 action_type text not null default 'none' check(action_type in ('none','event','combo','cipher','rewards','chat','store','update','dismiss')),
 action_label text check(action_label is null or char_length(action_label) between 1 and 32), action_payload jsonb not null default '{}'::jsonb,
 starts_at timestamptz, ends_at timestamptz, status text not null default 'draft' check(status in ('draft','scheduled','active','paused','ended','cancelled')),
 repeat_mode text not null default 'once_per_session' check(repeat_mode in ('once_per_session','once_per_user','daily','interval','until_dismissed','limited','continuous')),
 repeat_interval_minutes integer check(repeat_interval_minutes between 5 and 10080), max_impressions_per_user integer check(max_impressions_per_user between 1 and 100),
 dismissible boolean not null default true, published_by uuid references auth.users(id) on delete restrict, published_at timestamptz,
 stopped_by uuid references auth.users(id) on delete restrict, stopped_at timestamptz, created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 version integer not null default 1 check(version>0), check(ends_at is null or starts_at is null or ends_at>starts_at),
 check(jsonb_typeof(action_payload)='object')
);
create table public.marino_announcement_targets (
 announcement_id uuid primary key references public.marino_announcements(id) on delete cascade,
 target_type text not null check(target_type in ('all','league','level_range','new_users','active_users','country','language','specific_user','non_banned','admins','event_participants')),
 target_rules jsonb not null default '{}'::jsonb check(jsonb_typeof(target_rules)='object'), updated_at timestamptz not null default now()
);
create table public.marino_announcement_impressions (
 id bigint generated always as identity primary key, announcement_id uuid not null references public.marino_announcements(id) on delete cascade,
 auth_user_id uuid not null references auth.users(id) on delete cascade, announcement_version integer not null check(announcement_version>0),
 request_id uuid not null, action_clicked boolean not null default false, seen_at timestamptz not null default now(),
 unique(auth_user_id,request_id)
);
create index marino_announcement_impression_lookup on public.marino_announcement_impressions(auth_user_id,announcement_id,seen_at desc);
create table public.marino_announcement_dismissals (
 announcement_id uuid not null references public.marino_announcements(id) on delete cascade, auth_user_id uuid not null references auth.users(id) on delete cascade,
 announcement_version integer not null check(announcement_version>0), request_id uuid not null, dismissed_at timestamptz not null default now(),
 primary key(announcement_id,auth_user_id,announcement_version), unique(auth_user_id,request_id)
);
create table public.marino_announcement_signals (
 id bigint generated always as identity primary key, announcement_id uuid not null, version integer not null,
 signal text not null check(signal in ('refresh','stop')), created_at timestamptz not null default now()
);
create index marino_announcement_signals_created on public.marino_announcement_signals(created_at desc);

insert into public.marino_admin_action_policies(action,permission_key,critical) values
('announcements_list','announcements.view',false),('announcement_get','announcements.view',false),
('announcement_create','announcements.create',false),('announcement_update','announcements.create',false),
('announcement_preview','announcements.view',false),('announcement_publish','announcements.publish',true),
('announcement_pause','announcements.stop',false),('announcement_resume','announcements.publish',true),
('announcement_stop','announcements.stop',true),('announcement_delete','announcements.delete',true),
('announcement_stats','announcements.view',false);

create or replace function public.marino_announcement_validate(p_payload jsonb)
returns void language plpgsql immutable security definer set search_path = pg_catalog, public as $$
declare v_target text:=coalesce(p_payload->>'target_type','all'); v_action text:=coalesce(p_payload->>'action_type','none');
begin
 if jsonb_typeof(p_payload)<>'object' then raise exception 'invalid_announcement_payload'; end if;
 if char_length(btrim(coalesce(p_payload->>'title',''))) not between 1 and 80 or char_length(btrim(coalesce(p_payload->>'message',''))) not between 1 and 500 then raise exception 'invalid_announcement_text'; end if;
 if coalesce(p_payload->>'announcement_type','') not in ('general','info','event','reward','update','maintenance','emergency','campaign','system') then raise exception 'invalid_announcement_type'; end if;
 if coalesce(p_payload->>'priority','normal') not in ('low','normal','high','critical') then raise exception 'invalid_announcement_priority'; end if;
 if v_action not in ('none','event','combo','cipher','rewards','chat','store','update','dismiss') or p_payload ? 'external_url' then raise exception 'invalid_announcement_action'; end if;
 if v_target not in ('all','league','level_range','new_users','active_users','country','language','specific_user','non_banned','admins','event_participants') then raise exception 'invalid_announcement_target'; end if;
 if v_target='specific_user' and coalesce(p_payload#>>'{target_rules,auth_user_id}','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'invalid_target_user'; end if;
 if coalesce(p_payload->>'repeat_mode','once_per_session') not in ('once_per_session','once_per_user','daily','interval','until_dismissed','limited','continuous') then raise exception 'invalid_repeat_mode'; end if;
end $$;

create or replace function public.marino_announcement_signal()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin insert into public.marino_announcement_signals(announcement_id,version,signal) values(new.id,new.version,case when new.status in ('active','scheduled') then 'refresh' else 'stop' end); return new; end $$;
create trigger marino_announcement_signal after insert or update of status,version on public.marino_announcements for each row execute function public.marino_announcement_signal();

create or replace function public.marino_announcement_is_targeted(p_announcement uuid,p_user uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
 select exists(select 1 from public.marino_announcement_targets t join public.marino_identity_links l on l.auth_user_id=p_user join public.marino_players p on p.telegram_id=l.telegram_id
 left join public.marino_admin_memberships m on m.auth_user_id=p_user and m.active and (m.expires_at is null or m.expires_at>now())
 where t.announcement_id=p_announcement and case t.target_type
  when 'all' then true when 'non_banned' then not p.is_banned when 'language' then p.language_code=t.target_rules->>'language'
  when 'country' then p.country_code=t.target_rules->>'country' when 'specific_user' then p_user=(t.target_rules->>'auth_user_id')::uuid
  when 'admins' then m.auth_user_id is not null when 'new_users' then p.created_at>now()-make_interval(days=>least(30,greatest(1,coalesce((t.target_rules->>'days')::integer,7))))
  when 'active_users' then l.last_verified_at>now()-make_interval(days=>least(30,greatest(1,coalesce((t.target_rules->>'days')::integer,7))))
  when 'level_range' then p.casino_level between greatest(1,coalesce((t.target_rules->>'min')::integer,1)) and least(9999,coalesce((t.target_rules->>'max')::integer,9999))
  when 'league' then p.casino_level between greatest(1,coalesce((t.target_rules->>'min_level')::integer,1)) and least(9999,coalesce((t.target_rules->>'max_level')::integer,9999))
  else false end)
$$;

create or replace function public.marino_announcement_player_rpc(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_id uuid; v_version integer; v_result jsonb;
begin
 if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
 if p_payload ?| array['auth_user_id','telegram_id','target_rules','status'] then raise exception 'caller_identity_not_allowed'; end if;
 if p_action='active_announcements' then
  select jsonb_build_object('ok',true,'server_time',now(),'items',coalesce(jsonb_agg(to_jsonb(x) order by x.priority_order desc,x.starts_at),'[]'::jsonb)) into v_result from (
   select a.id,a.title,a.message,a.icon,a.announcement_type,a.priority,a.visual_template,a.action_type,a.action_label,a.action_payload,a.starts_at,a.ends_at,a.repeat_mode,a.dismissible,a.version,
    case a.priority when 'critical' then 4 when 'high' then 3 when 'normal' then 2 else 1 end priority_order
   from public.marino_announcements a where a.status='active' and coalesce(a.starts_at,now())<=now() and coalesce(a.ends_at,now()+interval '1 day')>now()
   and public.marino_announcement_is_targeted(a.id,v_user)
   and not exists(select 1 from public.marino_announcement_dismissals d where d.announcement_id=a.id and d.auth_user_id=v_user and d.announcement_version=a.version)
   and (a.max_impressions_per_user is null or (select count(*) from public.marino_announcement_impressions i where i.announcement_id=a.id and i.auth_user_id=v_user and i.announcement_version=a.version)<a.max_impressions_per_user)
   and (a.repeat_mode not in ('once_per_user','daily','interval') or not exists(select 1 from public.marino_announcement_impressions i where i.announcement_id=a.id and i.auth_user_id=v_user and i.announcement_version=a.version and
      (a.repeat_mode='once_per_user' or (a.repeat_mode='daily' and i.seen_at>=date_trunc('day',now())) or (a.repeat_mode='interval' and i.seen_at>now()-make_interval(mins=>a.repeat_interval_minutes)))))
  ) x;
 elsif p_action in ('announcement_mark_seen','announcement_dismiss','announcement_action') then
  if p_request_id is null then raise exception 'request_id_required'; end if; v_id:=(p_payload->>'announcement_id')::uuid; v_version:=(p_payload->>'version')::integer;
  if not exists(select 1 from public.marino_announcements a where a.id=v_id and a.version=v_version and a.status='active' and coalesce(a.starts_at,now())<=now() and coalesce(a.ends_at,now()+interval '1 day')>now() and public.marino_announcement_is_targeted(a.id,v_user)) then raise exception 'announcement_not_available' using errcode='42501'; end if;
  if p_action='announcement_dismiss' then
   if not exists(select 1 from public.marino_announcements where id=v_id and dismissible) then raise exception 'announcement_not_dismissible'; end if;
   insert into public.marino_announcement_dismissals(announcement_id,auth_user_id,announcement_version,request_id) values(v_id,v_user,v_version,p_request_id) on conflict(announcement_id,auth_user_id,announcement_version) do nothing;
  else insert into public.marino_announcement_impressions(announcement_id,auth_user_id,announcement_version,request_id,action_clicked) values(v_id,v_user,v_version,p_request_id,p_action='announcement_action') on conflict(auth_user_id,request_id) do nothing; end if;
  v_result:=jsonb_build_object('ok',true);
 else raise exception 'announcement_action_not_allowed' using errcode='42501'; end if;
 return v_result;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then raise exception 'invalid_payload_value';
end $$;

create or replace function public.marino_announcement_admin_rpc(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_policy public.marino_admin_action_policies; v_member public.marino_admin_memberships; v_id uuid; v_before jsonb; v_after jsonb; v_result jsonb; v_reason text:=btrim(coalesce(p_payload->>'reason',''));
begin
 select * into v_policy from public.marino_admin_action_policies where action=p_action and action like 'announcement%'; if v_policy.action is null then raise exception 'announcement_admin_action_not_allowed' using errcode='42501'; end if;
 v_member:=public.marino_admin_require(v_policy.permission_key,v_policy.critical); if p_request_id is null then raise exception 'request_id_required'; end if;
 insert into public.marino_admin_request_keys(auth_user_id,request_id,action) values(v_member.auth_user_id,p_request_id,p_action) on conflict do nothing; if not found then select response into v_result from public.marino_admin_request_keys where auth_user_id=v_member.auth_user_id and request_id=p_request_id; return coalesce(v_result,jsonb_build_object('ok',false,'pending',true)); end if;
 if v_policy.critical and (char_length(v_reason)<8 or coalesce((p_payload->>'confirmed')::boolean,false) is not true) then raise exception 'critical_confirmation_required'; end if;
 if p_action='announcements_list' then select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)) into v_result from (select a.id,a.title,a.announcement_type,a.priority,a.status,a.starts_at,a.ends_at,a.version,a.updated_at,t.target_type from public.marino_announcements a join public.marino_announcement_targets t on t.announcement_id=a.id order by a.updated_at desc limit least(200,greatest(1,coalesce((p_payload->>'limit')::integer,50)))) x;
 elsif p_action in ('announcement_get','announcement_preview') then v_id:=(p_payload->>'announcement_id')::uuid; select jsonb_build_object('ok',true,'announcement',to_jsonb(a),'target',to_jsonb(t)) into v_result from public.marino_announcements a join public.marino_announcement_targets t on t.announcement_id=a.id where a.id=v_id;
 elsif p_action='announcement_create' then
  perform public.marino_announcement_validate(p_payload); insert into public.marino_announcements(title,message,icon,announcement_type,priority,visual_template,action_type,action_label,action_payload,starts_at,ends_at,status,repeat_mode,repeat_interval_minutes,max_impressions_per_user,dismissible,created_by,updated_by)
  values(btrim(p_payload->>'title'),btrim(p_payload->>'message'),left(coalesce(p_payload->>'icon','📢'),16),p_payload->>'announcement_type',coalesce(p_payload->>'priority','normal'),coalesce(p_payload->>'visual_template','blue'),coalesce(p_payload->>'action_type','none'),nullif(left(p_payload->>'action_label',32),''),coalesce(p_payload->'action_payload','{}'::jsonb),(p_payload->>'starts_at')::timestamptz,(p_payload->>'ends_at')::timestamptz,'draft',coalesce(p_payload->>'repeat_mode','once_per_session'),(p_payload->>'repeat_interval_minutes')::integer,(p_payload->>'max_impressions_per_user')::integer,coalesce((p_payload->>'dismissible')::boolean,true),v_member.auth_user_id,v_member.auth_user_id) returning id into v_id;
  insert into public.marino_announcement_targets(announcement_id,target_type,target_rules) values(v_id,coalesce(p_payload->>'target_type','all'),coalesce(p_payload->'target_rules','{}'::jsonb)); v_after:=p_payload-array['reason','confirmed']; v_result:=jsonb_build_object('ok',true,'announcement_id',v_id);
 elsif p_action='announcement_update' then
  perform public.marino_announcement_validate(p_payload); v_id:=(p_payload->>'announcement_id')::uuid; select to_jsonb(a) into v_before from public.marino_announcements a where id=v_id and status in ('draft','scheduled','paused'); if v_before is null then raise exception 'announcement_not_editable'; end if;
  update public.marino_announcements set title=btrim(p_payload->>'title'),message=btrim(p_payload->>'message'),icon=left(coalesce(p_payload->>'icon','📢'),16),announcement_type=p_payload->>'announcement_type',priority=coalesce(p_payload->>'priority','normal'),visual_template=coalesce(p_payload->>'visual_template','blue'),action_type=coalesce(p_payload->>'action_type','none'),action_label=nullif(left(p_payload->>'action_label',32),''),action_payload=coalesce(p_payload->'action_payload','{}'::jsonb),starts_at=(p_payload->>'starts_at')::timestamptz,ends_at=(p_payload->>'ends_at')::timestamptz,repeat_mode=coalesce(p_payload->>'repeat_mode','once_per_session'),repeat_interval_minutes=(p_payload->>'repeat_interval_minutes')::integer,max_impressions_per_user=(p_payload->>'max_impressions_per_user')::integer,dismissible=coalesce((p_payload->>'dismissible')::boolean,true),updated_by=v_member.auth_user_id,updated_at=now(),version=version+1 where id=v_id;
  update public.marino_announcement_targets set target_type=coalesce(p_payload->>'target_type','all'),target_rules=coalesce(p_payload->'target_rules','{}'::jsonb),updated_at=now() where announcement_id=v_id; v_after:=p_payload-array['reason','confirmed']; v_result:=jsonb_build_object('ok',true,'announcement_id',v_id);
 elsif p_action in ('announcement_publish','announcement_resume') then
  v_id:=(p_payload->>'announcement_id')::uuid; select to_jsonb(a) into v_before from public.marino_announcements a where id=v_id for update; if v_before is null then raise exception 'announcement_not_found'; end if;
  update public.marino_announcements set status=case when coalesce(starts_at,now())>now() then 'scheduled' else 'active' end,published_by=v_member.auth_user_id,published_at=now(),stopped_by=null,stopped_at=null,updated_by=v_member.auth_user_id,updated_at=now(),version=version+1 where id=v_id and status in ('draft','scheduled','paused'); if not found then raise exception 'announcement_not_publishable'; end if; select to_jsonb(a) into v_after from public.marino_announcements a where id=v_id; v_result:=jsonb_build_object('ok',true,'announcement_id',v_id,'status',v_after->>'status');
 elsif p_action in ('announcement_pause','announcement_stop') then
  v_id:=(p_payload->>'announcement_id')::uuid; select to_jsonb(a) into v_before from public.marino_announcements a where id=v_id for update; update public.marino_announcements set status=case when p_action='announcement_pause' then 'paused' else 'cancelled' end,stopped_by=v_member.auth_user_id,stopped_at=now(),updated_by=v_member.auth_user_id,updated_at=now(),version=version+1 where id=v_id and status in ('active','scheduled','paused'); if not found then raise exception 'announcement_not_stoppable'; end if; select to_jsonb(a) into v_after from public.marino_announcements a where id=v_id; v_result:=jsonb_build_object('ok',true);
 elsif p_action='announcement_delete' then v_id:=(p_payload->>'announcement_id')::uuid; select to_jsonb(a) into v_before from public.marino_announcements a where id=v_id and status in ('draft','cancelled','ended'); if v_before is null then raise exception 'announcement_not_deletable'; end if; delete from public.marino_announcements where id=v_id; v_result:=jsonb_build_object('ok',true);
 elsif p_action='announcement_stats' then v_id:=(p_payload->>'announcement_id')::uuid; select jsonb_build_object('ok',true,'impressions',count(*),'unique_users',count(distinct auth_user_id),'clicks',count(*) filter(where action_clicked),'dismissals',(select count(*) from public.marino_announcement_dismissals where announcement_id=v_id)) into v_result from public.marino_announcement_impressions where announcement_id=v_id;
 else raise exception 'announcement_admin_action_not_implemented'; end if;
 insert into public.marino_admin_audit_details(admin_auth_user_id,admin_role,permission_key,action,target_type,target_id,before_state,after_state,reason,request_id,result) values(v_member.auth_user_id,v_member.role,v_policy.permission_key,p_action,'announcement',v_id::text,v_before,v_after,nullif(v_reason,''),p_request_id,'succeeded');
 update public.marino_admin_request_keys set response=v_result where auth_user_id=v_member.auth_user_id and request_id=p_request_id; return v_result;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then raise exception 'invalid_payload_value';
end $$;

do $$ declare t text; begin foreach t in array array['marino_announcements','marino_announcement_targets','marino_announcement_impressions','marino_announcement_dismissals','marino_announcement_signals'] loop execute format('alter table public.%I enable row level security',t); execute format('revoke all on table public.%I from public,anon,authenticated',t); end loop; end $$;
revoke all on sequence public.marino_announcement_impressions_id_seq from public,anon,authenticated;
revoke all on sequence public.marino_announcement_signals_id_seq from public,anon,authenticated;
create policy marino_announcement_signal_read on public.marino_announcement_signals for select to authenticated using(auth.uid() is not null);
grant select on public.marino_announcement_signals to authenticated;
do $$ begin if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='marino_announcement_signals') then alter publication supabase_realtime add table public.marino_announcement_signals; end if; end $$;
revoke all on function public.marino_announcement_validate(jsonb) from public,anon,authenticated;
revoke all on function public.marino_announcement_signal() from public,anon,authenticated;
revoke all on function public.marino_announcement_is_targeted(uuid,uuid) from public,anon,authenticated;
revoke all on function public.marino_announcement_player_rpc(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_announcement_player_rpc(text,jsonb,uuid) to authenticated;
revoke all on function public.marino_announcement_admin_rpc(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_announcement_admin_rpc(text,jsonb,uuid) to authenticated;

commit;
