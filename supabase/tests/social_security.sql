-- Run after migrations in staging/production. It changes no data.
begin read only;

do $$
declare v_missing text;
begin
  select string_agg(name, ', ') into v_missing
  from (values
    ('marino_social_profiles'),('marino_chat_messages'),('marino_chat_blocks'),('marino_chat_reports'),
    ('marino_friend_requests'),('marino_friendships'),('marino_gift_catalog'),('marino_gift_transactions'),('marino_social_stats')
  ) expected(name)
  where to_regclass('public.' || name) is null;
  if v_missing is not null then raise exception 'missing social tables: %', v_missing; end if;

  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname like 'marino_%'
      and c.relname in ('marino_social_profiles','marino_chat_messages','marino_chat_blocks','marino_chat_reports','marino_friend_requests','marino_friendships','marino_gift_catalog','marino_gift_transactions','marino_social_stats')
      and not c.relrowsecurity
  ) then raise exception 'social RLS is not enabled'; end if;

  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name like 'marino_%'
      and table_name in ('marino_social_profiles','marino_chat_messages','marino_chat_blocks','marino_chat_reports','marino_friend_requests','marino_friendships','marino_gift_catalog','marino_gift_transactions','marino_social_stats')
      and grantee in ('PUBLIC','anon','authenticated')
  ) then raise exception 'direct social table grant detected'; end if;

  if has_function_privilege('anon','public.marino_social_rpc(text,jsonb,uuid)','EXECUTE') then raise exception 'anon can execute social gateway'; end if;
  if not has_function_privilege('authenticated','public.marino_social_rpc(text,jsonb,uuid)','EXECUTE') then raise exception 'authenticated cannot execute social gateway'; end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'marino_social%' and p.prosecdef
      and coalesce(array_to_string(p.proconfig,','),'') not like '%search_path=pg_catalog, public%'
  ) then raise exception 'unsafe social SECURITY DEFINER search_path'; end if;
end $$;

rollback;
