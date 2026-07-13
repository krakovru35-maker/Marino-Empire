-- PHASE 5A server-authoritative content RPCs. PREPARE ONLY.

begin;

create or replace function public.content_admin_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select role from public.content_admin_users
  where auth_user_id = auth.uid() and active and (expires_at is null or expires_at > now())
$$;

create or replace function public.content_normalize_answer(p_answer text, p_mode text)
returns text
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case p_mode
    when 'nfkc_upper_trim' then upper(regexp_replace(normalize(trim(coalesce(p_answer,'')), NFKC), '\s+', ' ', 'g'))
    when 'json_exact' then normalize(trim(coalesce(p_answer,'')), NFKC)
    else lower(regexp_replace(normalize(trim(coalesce(p_answer,'')), NFKC), '\s+', ' ', 'g'))
  end
$$;

create or replace function public.get_active_daily_content(p_language text default 'tr')
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_user uuid := auth.uid(); v_result jsonb;
begin
  if v_user is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  if p_language not in ('tr','en') then p_language := 'tr'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'content_type',c.content_type,
    'title',case when p_language='en' then c.title_en else c.title_tr end,
    'description',case when p_language='en' then c.description_en else c.description_tr end,
    'payload',c.payload - array['answer','solution','correct_answer','combo_order','cipher_answer'],
    'starts_at',c.starts_at,'ends_at',c.ends_at,'server_time',now(),
    'reward_type',c.reward_type,'reward_amount',c.reward_amount,'version',c.version,
    'claim_status',coalesce(cl.claim_status,'available')
  ) order by c.content_type), '[]'::jsonb) into v_result
  from public.daily_content c
  left join public.player_content_claims cl on cl.content_id=c.id and cl.user_id=v_user
  where c.status='published' and c.starts_at<=now() and c.ends_at>now();
  return v_result;
end
$$;

create or replace function public.submit_daily_content_answer(
  p_content_id uuid, p_answer text, p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_user uuid := auth.uid(); v_content public.daily_content%rowtype; v_existing public.player_content_attempts%rowtype; v_correct boolean; v_attempts integer;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'request_id_required'; end if;
  if char_length(coalesce(p_answer,'')) not between 1 and 512 then raise exception 'answer_length_invalid'; end if;
  select * into v_existing from public.player_content_attempts where user_id=v_user and request_id=p_request_id;
  if found then return jsonb_build_object('correct',v_existing.is_correct,'eligible',v_existing.is_correct,'idempotent',true); end if;
  select * into v_content from public.daily_content where id=p_content_id for share;
  if not found or v_content.status<>'published' or v_content.starts_at>now() or v_content.ends_at<=now() then raise exception 'content_not_active'; end if;
  if v_content.content_type not in ('daily_combo','daily_cipher') then raise exception 'answer_not_supported'; end if;
  select count(*) into v_attempts from public.player_content_attempts
    where user_id=v_user and content_id=p_content_id and attempted_at>now()-interval '5 minutes';
  if v_attempts>=6 then raise exception 'answer_rate_limited' using errcode='P0001'; end if;
  v_correct := extensions.crypt(public.content_normalize_answer(p_answer,v_content.answer_normalization),v_content.answer_hash)=v_content.answer_hash;
  insert into public.player_content_attempts(user_id,content_id,attempt_payload,is_correct,request_id,metadata)
  values(v_user,p_content_id,jsonb_build_object('answer_length',char_length(p_answer)),v_correct,p_request_id,jsonb_build_object('normalization',v_content.answer_normalization));
  return jsonb_build_object('correct',v_correct,'eligible',v_correct,'idempotent',false,'attempts_remaining',greatest(0,5-v_attempts));
end
$$;

create or replace function public.claim_daily_content_reward(
  p_content_id uuid, p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_user uuid:=auth.uid(); v_content public.daily_content%rowtype; v_claim_id uuid; v_entitlement uuid; v_existing public.player_content_claims%rowtype;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'request_id_required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text||':'||p_content_id::text,0));
  select * into v_existing from public.player_content_claims where user_id=v_user and content_id=p_content_id;
  if found then return jsonb_build_object('claimed',true,'idempotent',v_existing.request_id=p_request_id,'reward_type',v_existing.reward_type,'reward_amount',v_existing.reward_amount,'entitlement_id',v_existing.entitlement_id); end if;
  select * into v_content from public.daily_content where id=p_content_id for share;
  if not found or v_content.status<>'published' or now()<v_content.starts_at or now()>=v_content.ends_at+interval '15 minutes' then raise exception 'claim_window_closed'; end if;
  if v_content.content_type in ('daily_combo','daily_cipher') and not exists(
    select 1 from public.player_content_attempts where user_id=v_user and content_id=p_content_id and is_correct
  ) then raise exception 'correct_attempt_required'; end if;
  if v_content.reward_type in ('demo_free_spin','demo_free_bet','cosmetic') then
    insert into public.virtual_entitlements(user_id,entitlement_type,quantity,remaining_quantity,source_type,source_id,starts_at,expires_at)
    values(v_user,v_content.reward_type,v_content.reward_amount,v_content.reward_amount,'daily_content',v_content.id,now(),v_content.ends_at+interval '15 minutes') returning id into v_entitlement;
  elsif v_content.reward_type='reward_point' then
    insert into public.player_reward_point_balances(user_id,balance) values(v_user,v_content.reward_amount)
    on conflict(user_id) do update set balance=public.player_reward_point_balances.balance+excluded.balance,updated_at=now();
  end if;
  insert into public.player_content_claims(user_id,content_id,reward_type,reward_amount,claim_status,request_id,entitlement_id)
  values(v_user,v_content.id,v_content.reward_type,v_content.reward_amount,'claimed',p_request_id,v_entitlement) returning id into v_claim_id;
  return jsonb_build_object('claimed',true,'idempotent',false,'claim_id',v_claim_id,'reward_type',v_content.reward_type,'reward_amount',v_content.reward_amount,'entitlement_id',v_entitlement);
end
$$;

create or replace function public.admin_upsert_daily_content(
  p_content_id uuid default null, p_document jsonb default '{}'::jsonb, p_answer text default null,
  p_expected_version integer default null, p_request_id uuid default gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_user uuid:=auth.uid(); v_role text:=public.content_admin_role(); v_before public.daily_content%rowtype; v_after public.daily_content%rowtype; v_hash text; v_starts timestamptz; v_ends timestamptz; v_reward text; v_amount integer;
begin
  if v_role not in ('editor','publisher','super_admin') then raise exception 'editor_role_required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'request_id_required'; end if;
  if p_document::text ~* '"(answer|solution|correct_answer|combo_order|cipher_answer)"\s*:' then raise exception 'secret_in_public_payload'; end if;
  v_starts:=(p_document->>'starts_at')::timestamptz; v_ends:=(p_document->>'ends_at')::timestamptz;
  v_reward:=coalesce(p_document->>'reward_type','none'); v_amount:=coalesce((p_document->>'reward_amount')::integer,0);
  if v_ends<=v_starts then raise exception 'invalid_schedule'; end if;
  if v_reward not in ('reward_point','demo_free_spin','demo_free_bet','cosmetic','none') then raise exception 'reward_not_allowed'; end if;
  if v_amount<0 or v_amount>1000000 or (v_reward='none')<>(v_amount=0) then raise exception 'reward_amount_invalid'; end if;
  if p_answer is not null then v_hash:=extensions.crypt(public.content_normalize_answer(p_answer,coalesce(p_document->>'answer_normalization','nfkc_lower_trim')),extensions.gen_salt('bf',10)); end if;
  if p_content_id is null then
    insert into public.daily_content(content_type,title_tr,title_en,description_tr,description_en,payload,starts_at,ends_at,status,reward_type,reward_amount,answer_hash,answer_normalization,created_by,updated_by)
    values(p_document->>'content_type',p_document->>'title_tr',p_document->>'title_en',coalesce(p_document->>'description_tr',''),coalesce(p_document->>'description_en',''),coalesce(p_document->'payload','{}'::jsonb),v_starts,v_ends,coalesce(p_document->>'status','draft'),v_reward,v_amount,v_hash,coalesce(p_document->>'answer_normalization','nfkc_lower_trim'),v_user,v_user) returning * into v_after;
  else
    select * into v_before from public.daily_content where id=p_content_id for update;
    if not found then raise exception 'content_not_found'; end if;
    if v_before.version<>p_expected_version then raise exception 'version_conflict'; end if;
    if v_before.status='published' then raise exception 'published_content_immutable'; end if;
    update public.daily_content set content_type=p_document->>'content_type',title_tr=p_document->>'title_tr',title_en=p_document->>'title_en',description_tr=coalesce(p_document->>'description_tr',''),description_en=coalesce(p_document->>'description_en',''),payload=coalesce(p_document->'payload','{}'::jsonb),starts_at=v_starts,ends_at=v_ends,status=coalesce(p_document->>'status','draft'),reward_type=v_reward,reward_amount=v_amount,answer_hash=coalesce(v_hash,answer_hash),answer_normalization=coalesce(p_document->>'answer_normalization',answer_normalization),updated_by=v_user,version=version+1 where id=p_content_id and version=p_expected_version returning * into v_after;
    if not found then raise exception 'version_conflict'; end if;
  end if;
  insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,before_data,after_data,request_id)
  values(v_user,'content_upsert','daily_content',v_after.id,to_jsonb(v_before)-array['answer_hash'],to_jsonb(v_after)-array['answer_hash'],p_request_id);
  return to_jsonb(v_after)-array['answer_hash','created_by','updated_by'];
end
$$;

create or replace function public.admin_publish_daily_content(p_content_id uuid,p_expected_version integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_user uuid:=auth.uid(); v_role text:=public.content_admin_role(); v_before public.daily_content%rowtype; v_after public.daily_content%rowtype;
begin
  if v_role not in ('publisher','super_admin') then raise exception 'publisher_role_required' using errcode='42501'; end if;
  select * into v_before from public.daily_content where id=p_content_id for update;
  if not found or v_before.version<>p_expected_version then raise exception 'version_conflict'; end if;
  if exists(select 1 from public.daily_content c where c.id<>p_content_id and c.content_type=v_before.content_type and c.status='published' and tstzrange(c.starts_at,c.ends_at,'[)')&&tstzrange(v_before.starts_at,v_before.ends_at,'[)')) then raise exception 'published_schedule_overlap'; end if;
  update public.daily_content set status='published',published_at=now(),updated_by=v_user,version=version+1 where id=p_content_id returning * into v_after;
  insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,before_data,after_data,request_id) values(v_user,'content_publish','daily_content',p_content_id,to_jsonb(v_before)-array['answer_hash'],to_jsonb(v_after)-array['answer_hash'],p_request_id);
  return to_jsonb(v_after)-array['answer_hash','created_by','updated_by'];
end
$$;

create or replace function public.admin_cancel_daily_content(p_content_id uuid,p_expected_version integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_user uuid:=auth.uid(); v_role text:=public.content_admin_role(); v_before public.daily_content%rowtype; v_after public.daily_content%rowtype;
begin
  if v_role not in ('publisher','super_admin') then raise exception 'publisher_role_required' using errcode='42501'; end if;
  select * into v_before from public.daily_content where id=p_content_id for update;
  if not found or v_before.version<>p_expected_version then raise exception 'version_conflict'; end if;
  update public.daily_content set status='cancelled',ends_at=least(ends_at,now()),updated_by=v_user,version=version+1 where id=p_content_id returning * into v_after;
  insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,before_data,after_data,request_id) values(v_user,'content_cancel','daily_content',p_content_id,to_jsonb(v_before)-array['answer_hash'],to_jsonb(v_after)-array['answer_hash'],p_request_id);
  return to_jsonb(v_after)-array['answer_hash','created_by','updated_by'];
end
$$;

create or replace function public.admin_get_daily_content()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_role text:=public.content_admin_role(); v_result jsonb;
begin
  if v_role not in ('viewer','editor','publisher','super_admin') then raise exception 'admin_role_required' using errcode='42501'; end if;
  select coalesce(jsonb_agg(to_jsonb(c)-array['answer_hash','created_by','updated_by'] order by c.starts_at desc),'[]'::jsonb) into v_result from public.daily_content c;
  return jsonb_build_object('role',v_role,'items',v_result);
end
$$;

create or replace function public.admin_get_content_audit(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_role text:=public.content_admin_role(); v_result jsonb;
begin
  if v_role not in ('viewer','editor','publisher','super_admin') then raise exception 'admin_role_required' using errcode='42501'; end if;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc),'[]'::jsonb) into v_result from (select * from public.admin_audit_log order by created_at desc limit least(greatest(p_limit,1),250)) a;
  return v_result;
end
$$;

revoke all on function public.content_admin_role() from public,anon,authenticated;
revoke all on function public.content_normalize_answer(text,text) from public,anon,authenticated;
revoke all on function public.get_active_daily_content(text) from public,anon;
revoke all on function public.submit_daily_content_answer(uuid,text,uuid) from public,anon;
revoke all on function public.claim_daily_content_reward(uuid,uuid) from public,anon;
revoke all on function public.admin_upsert_daily_content(uuid,jsonb,text,integer,uuid) from public,anon;
revoke all on function public.admin_publish_daily_content(uuid,integer,uuid) from public,anon;
revoke all on function public.admin_cancel_daily_content(uuid,integer,uuid) from public,anon;
revoke all on function public.admin_get_daily_content() from public,anon;
revoke all on function public.admin_get_content_audit(integer) from public,anon;
grant execute on function public.get_active_daily_content(text),public.submit_daily_content_answer(uuid,text,uuid),public.claim_daily_content_reward(uuid,uuid),public.admin_upsert_daily_content(uuid,jsonb,text,integer,uuid),public.admin_publish_daily_content(uuid,integer,uuid),public.admin_cancel_daily_content(uuid,integer,uuid),public.admin_get_daily_content(),public.admin_get_content_audit(integer) to authenticated;

commit;
