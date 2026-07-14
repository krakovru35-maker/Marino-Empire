-- Scheduled delivery and target-rule validation for live announcements.
begin;

create or replace function public.marino_announcement_validate(p_payload jsonb)
returns void language plpgsql immutable security definer set search_path = pg_catalog, public as $$
declare v_target text:=coalesce(p_payload->>'target_type','all'); v_action text:=coalesce(p_payload->>'action_type','none'); v_rules jsonb:=coalesce(p_payload->'target_rules','{}'::jsonb);
begin
 if jsonb_typeof(p_payload)<>'object' or jsonb_typeof(v_rules)<>'object' then raise exception 'invalid_announcement_payload'; end if;
 if char_length(btrim(coalesce(p_payload->>'title',''))) not between 1 and 80 or char_length(btrim(coalesce(p_payload->>'message',''))) not between 1 and 500 then raise exception 'invalid_announcement_text'; end if;
 if coalesce(p_payload->>'announcement_type','') not in ('general','info','event','reward','update','maintenance','emergency','campaign','system') then raise exception 'invalid_announcement_type'; end if;
 if coalesce(p_payload->>'priority','normal') not in ('low','normal','high','critical') then raise exception 'invalid_announcement_priority'; end if;
 if v_action not in ('none','event','combo','cipher','rewards','chat','store','update','dismiss') or p_payload ? 'external_url' then raise exception 'invalid_announcement_action'; end if;
 if v_target not in ('all','league','level_range','new_users','active_users','country','language','specific_user','non_banned','admins','event_participants') then raise exception 'invalid_announcement_target'; end if;
 if v_target='specific_user' and coalesce(v_rules->>'auth_user_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'invalid_target_user'; end if;
 if v_target='language' and coalesce(v_rules->>'language','') !~ '^[a-z]{2,8}$' then raise exception 'invalid_target_language'; end if;
 if v_target='country' and coalesce(v_rules->>'country','') !~ '^[A-Z]{2}$' then raise exception 'invalid_target_country'; end if;
 if v_target in ('new_users','active_users') and coalesce((v_rules->>'days')::integer,7) not between 1 and 30 then raise exception 'invalid_target_days'; end if;
 if v_target in ('level_range','league') and (coalesce((v_rules->>case when v_target='league' then 'min_level' else 'min' end)::integer,1) not between 1 and 9999 or coalesce((v_rules->>case when v_target='league' then 'max_level' else 'max' end)::integer,9999) not between 1 and 9999) then raise exception 'invalid_target_level'; end if;
 if coalesce(p_payload->>'repeat_mode','once_per_session') not in ('once_per_session','once_per_user','daily','interval','until_dismissed','limited','continuous') then raise exception 'invalid_repeat_mode'; end if;
end $$;

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
   from public.marino_announcements a where a.status in ('active','scheduled') and coalesce(a.starts_at,now())<=now() and coalesce(a.ends_at,now()+interval '1 day')>now()
   and public.marino_announcement_is_targeted(a.id,v_user)
   and not exists(select 1 from public.marino_announcement_dismissals d where d.announcement_id=a.id and d.auth_user_id=v_user and d.announcement_version=a.version)
   and (a.max_impressions_per_user is null or (select count(*) from public.marino_announcement_impressions i where i.announcement_id=a.id and i.auth_user_id=v_user and i.announcement_version=a.version)<a.max_impressions_per_user)
   and (a.repeat_mode not in ('once_per_user','daily','interval') or not exists(select 1 from public.marino_announcement_impressions i where i.announcement_id=a.id and i.auth_user_id=v_user and i.announcement_version=a.version and
      (a.repeat_mode='once_per_user' or (a.repeat_mode='daily' and i.seen_at>=date_trunc('day',now())) or (a.repeat_mode='interval' and i.seen_at>now()-make_interval(mins=>coalesce(a.repeat_interval_minutes,60))))))
  ) x;
 elsif p_action in ('announcement_mark_seen','announcement_dismiss','announcement_action') then
  if p_request_id is null then raise exception 'request_id_required'; end if; v_id:=(p_payload->>'announcement_id')::uuid; v_version:=(p_payload->>'version')::integer;
  if not exists(select 1 from public.marino_announcements a where a.id=v_id and a.version=v_version and a.status in ('active','scheduled') and coalesce(a.starts_at,now())<=now() and coalesce(a.ends_at,now()+interval '1 day')>now() and public.marino_announcement_is_targeted(a.id,v_user)) then raise exception 'announcement_not_available' using errcode='42501'; end if;
  if p_action='announcement_dismiss' then
   if not exists(select 1 from public.marino_announcements where id=v_id and dismissible) then raise exception 'announcement_not_dismissible'; end if;
   insert into public.marino_announcement_dismissals(announcement_id,auth_user_id,announcement_version,request_id) values(v_id,v_user,v_version,p_request_id) on conflict(announcement_id,auth_user_id,announcement_version) do nothing;
  else insert into public.marino_announcement_impressions(announcement_id,auth_user_id,announcement_version,request_id,action_clicked) values(v_id,v_user,v_version,p_request_id,p_action='announcement_action') on conflict(auth_user_id,request_id) do nothing; end if;
  v_result:=jsonb_build_object('ok',true);
 else raise exception 'announcement_action_not_allowed' using errcode='42501'; end if;
 return v_result;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then raise exception 'invalid_payload_value';
end $$;

revoke all on function public.marino_announcement_validate(jsonb) from public,anon,authenticated;
revoke all on function public.marino_announcement_player_rpc(text,jsonb,uuid) from public,anon;
grant execute on function public.marino_announcement_player_rpc(text,jsonb,uuid) to authenticated;

commit;
