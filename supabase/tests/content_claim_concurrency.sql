-- Structural concurrency contract. A two-session race is executed only after explicit staging-write approval.
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

select ok(position('pg_advisory_xact_lock' in pg_get_functiondef('public.claim_daily_content_reward(uuid,uuid)'::regprocedure))>0,'claim takes transaction advisory lock');
select ok(exists(select 1 from pg_constraint where conrelid='public.player_content_claims'::regclass and contype='u' and pg_get_constraintdef(oid) like '%user_id, content_id%'),'one claim per user and content');
select ok(exists(select 1 from pg_constraint where conrelid='public.player_content_claims'::regclass and contype='u' and pg_get_constraintdef(oid) like '%user_id, request_id%'),'claim request is idempotent');
select ok(exists(select 1 from pg_constraint where conrelid='public.virtual_entitlements'::regclass and contype='u' and pg_get_constraintdef(oid) like '%user_id, source_type, source_id, entitlement_type%'),'one entitlement per source');
select ok(position('insert into public.player_content_claims' in lower(pg_get_functiondef('public.claim_daily_content_reward(uuid,uuid)'::regprocedure)))>position('insert into public.virtual_entitlements' in lower(pg_get_functiondef('public.claim_daily_content_reward(uuid,uuid)'::regprocedure))),'entitlement and claim are in one function transaction');

select * from finish();
rollback;
