-- Run only against an isolated local/staging test database after PHASE 5A migrations.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_table('public','daily_content','daily_content exists');
select has_table('public','player_content_attempts','attempts exists');
select has_table('public','player_content_claims','claims exists');
select has_table('public','virtual_entitlements','entitlements exists');
select has_table('public','player_reward_point_balances','MRP balance exists');
select has_table('public','content_admin_users','admin role table exists');
select has_table('public','admin_audit_log','append-only audit exists');
select ok((select relrowsecurity from pg_class where oid='public.daily_content'::regclass),'daily_content RLS enabled');
select ok(not has_table_privilege('anon','public.daily_content','select'),'anon cannot read content');
select ok(not has_table_privilege('authenticated','public.player_content_attempts','insert'),'player cannot insert attempt');
select ok(not has_table_privilege('authenticated','public.player_content_claims','insert'),'player cannot insert claim');
select ok(not has_table_privilege('authenticated','public.virtual_entitlements','insert'),'player cannot insert entitlement');
select ok(not has_table_privilege('authenticated','public.admin_audit_log','update'),'client cannot edit audit');
select has_function('public','get_active_daily_content',array['text']::name[],'active content RPC exists');
select has_function('public','submit_daily_content_answer',array['uuid','text','uuid']::name[],'answer RPC exists');
select has_function('public','claim_daily_content_reward',array['uuid','uuid']::name[],'claim RPC exists');
select ok(not has_function_privilege('anon','public.claim_daily_content_reward(uuid,uuid)','execute'),'anon cannot claim');
select ok(has_function_privilege('authenticated','public.claim_daily_content_reward(uuid,uuid)','execute'),'authenticated can call guarded claim');
select throws_ok($$select public.claim_daily_content_reward(gen_random_uuid(),gen_random_uuid())$$,'42501','authentication_required','unauthenticated claim rejected');
select throws_ok($$select public.admin_publish_daily_content(gen_random_uuid(),1,gen_random_uuid())$$,'42501','publisher_role_required','non-admin publish rejected');

select * from finish();
rollback;
