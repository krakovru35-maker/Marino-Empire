-- Trusted admin role gateway. PREPARE ONLY.

begin;

create or replace function public.marino_admin_rpc(
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
  v_user uuid := auth.uid();
  v_role text;
  v_response jsonb;
  v_target text := p_payload->>'target_id';
begin
  select role into v_role
  from public.marino_admin_roles
  where auth_user_id = v_user and active and (expires_at is null or expires_at > now());
  if v_role is null then raise exception 'admin_role_required' using errcode = '42501'; end if;
  if p_payload ?| array['p_admin_id','admin_id','role','auth_user_id'] then raise exception 'caller_authorization_not_allowed'; end if;
  if p_request_id is null then raise exception 'request_id_required'; end if;

  insert into public.marino_admin_audit_log(auth_user_id, action, target_id, request_id, payload)
  values (v_user, p_action, v_target, p_request_id, p_payload - array['note'])
  on conflict (auth_user_id, request_id) do nothing;
  if not found then raise exception 'duplicate_admin_request'; end if;

  case p_action
    when 'get_users' then
      if v_role not in ('operator','security_admin') then raise exception 'insufficient_admin_role'; end if;
      v_response := to_jsonb(public.marino_admin_get_users('0'));
    when 'get_requests' then
      v_response := to_jsonb(public.marino_admin_get_requests('0'));
    when 'update_user' then
      if v_role <> 'security_admin' then raise exception 'security_admin_required'; end if;
      if v_target !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_target'; end if;
      if coalesce((p_payload->>'coin')::bigint, -1) not between 0 and 1000000000000 then raise exception 'invalid_coin'; end if;
      if coalesce((p_payload->>'chips')::bigint, -1) not between 0 and 1000000000 then raise exception 'invalid_chips'; end if;
      if coalesce((p_payload->>'prestige')::int, -1) not between 0 and 100000 then raise exception 'invalid_prestige'; end if;
      v_response := to_jsonb(public.marino_admin_update_user('0', v_target, (p_payload->>'coin')::bigint, (p_payload->>'chips')::bigint, (p_payload->>'prestige')::int));
    when 'toggle_ban' then
      if v_role <> 'security_admin' then raise exception 'security_admin_required'; end if;
      if v_target !~ '^[1-9][0-9]{0,19}$' then raise exception 'invalid_target'; end if;
      v_response := to_jsonb(public.marino_admin_toggle_ban('0', v_target));
    when 'resolve_request' then
      if v_role not in ('operator','security_admin') then raise exception 'insufficient_admin_role'; end if;
      if coalesce((p_payload->>'request_id')::bigint, 0) not between 1 and 2147483647 then raise exception 'invalid_request'; end if;
      if (p_payload->>'resolution') not in ('approved','rejected') then raise exception 'invalid_resolution'; end if;
      if char_length(coalesce(p_payload->>'note','')) > 500 then raise exception 'note_too_long'; end if;
      v_response := to_jsonb(public.marino_admin_resolve_request(
        '0', (p_payload->>'request_id')::integer, p_payload->>'resolution', coalesce(p_payload->>'note','')
      ));
    else
      raise exception 'admin_action_not_allowed' using errcode = '42501';
  end case;
  return v_response;
end
$$;

revoke all on function public.marino_admin_rpc(text,jsonb,uuid) from public, anon;
grant execute on function public.marino_admin_rpc(text,jsonb,uuid) to authenticated;

commit;
