-- Content admin reporting view through role-checked RPC. PREPARE ONLY.

begin;

create or replace function public.admin_get_daily_content()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_role text:=public.content_admin_role(); v_result jsonb;
begin
  if v_role not in ('viewer','editor','publisher','super_admin') then raise exception 'admin_role_required' using errcode='42501'; end if;
  select coalesce(jsonb_agg(
    (to_jsonb(c)-array['answer_hash','created_by','updated_by']) || jsonb_build_object(
      'attempt_count',(select count(*) from public.player_content_attempts a where a.content_id=c.id),
      'correct_count',(select count(*) from public.player_content_attempts a where a.content_id=c.id and a.is_correct),
      'claim_count',(select count(*) from public.player_content_claims cl where cl.content_id=c.id and cl.claim_status='claimed')
    ) order by c.starts_at desc
  ),'[]'::jsonb) into v_result from public.daily_content c;
  return jsonb_build_object('role',v_role,'items',v_result);
end
$$;

revoke all on function public.admin_get_daily_content() from public,anon;
grant execute on function public.admin_get_daily_content() to authenticated;

commit;
