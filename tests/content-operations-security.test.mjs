import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const schema=fs.readFileSync('supabase/migrations/202607140001_content_operations_schema.sql','utf8');
const rpc=fs.readFileSync('supabase/migrations/202607140002_content_operations_rpc.sql','utf8');
const report=fs.readFileSync('supabase/migrations/202607140003_content_admin_reporting.sql','utf8');
const edge=fs.readFileSync('supabase/functions/content-ops/index.ts','utf8');
const request=fs.readFileSync('supabase/functions/content-ops/request.ts','utf8');
const admin=fs.readFileSync('public/js/admin/content-admin.js','utf8');
const adapter=fs.readFileSync('public/js/daily-content-adapter.js','utf8');
const html=fs.readFileSync('public/index.html','utf8');

test('content schema contains the required authority tables',()=>{
  for(const table of ['daily_content','player_content_attempts','player_content_claims','virtual_entitlements','admin_audit_log','content_admin_users'])assert.match(schema,new RegExp(`create table public\\.${table}`));
  assert.match(schema,/reward_type in \('reward_point','demo_free_spin','demo_free_bet','cosmetic','none'\)/);
  assert.doesNotMatch(schema,/deposit|withdraw|real_money|cash_balance/i);
});

test('players can select only active published content and never secret columns',()=>{
  assert.match(schema,/status = 'published' and starts_at <= now\(\) and ends_at > now\(\)/);
  const grant=schema.match(/grant select \([\s\S]*?\)\s+on public\.daily_content to authenticated;/i)?.[0]||'';
  assert.ok(grant);
  assert.doesNotMatch(grant,/answer_hash|created_by|updated_by/);
});

test('attempt claim entitlement admin and audit writes are denied directly',()=>{
  for(const table of ['player_content_attempts','player_content_claims','virtual_entitlements','admin_audit_log'])assert.match(schema,new RegExp(`revoke all on table public\\.${table} from public, anon, authenticated`));
  assert.doesNotMatch(schema,/create policy[^;]+for insert/i);
  assert.doesNotMatch(schema,/create policy[^;]+for update[^;]+admin_audit_log/i);
});

test('answers are normalized hashed and removed from every public response',()=>{
  assert.match(rpc,/extensions\.crypt\(public\.content_normalize_answer/);
  assert.match(rpc,/extensions\.gen_salt\('bf',10\)/);
  assert.match(rpc,/c\.payload - array\['answer','solution','correct_answer','combo_order','cipher_answer'\]/);
  assert.doesNotMatch(adapter,/correct_answer|combo_order|cipher_answer/);
});

test('wrong answers cannot claim and attempts are rate limited',()=>{
  assert.match(rpc,/if v_attempts>=6 then raise exception 'answer_rate_limited'/);
  assert.match(rpc,/and is_correct\s*\) then raise exception 'correct_attempt_required'/);
  assert.match(rpc,/answer_length_invalid/);
});

test('request id and claim idempotency are enforced',()=>{
  assert.match(schema,/unique \(user_id, request_id\)/g);
  assert.match(schema,/unique \(user_id, content_id\)/);
  assert.match(rpc,/where user_id=v_user and request_id=p_request_id/);
  assert.match(rpc,/where user_id=v_user and content_id=p_content_id/);
});

test('concurrent claim is serialized and entitlement is transaction-bound',()=>{
  assert.match(rpc,/pg_advisory_xact_lock\(hashtextextended/);
  assert.match(schema,/unique \(user_id, source_type, source_id, entitlement_type\)/);
  const claim=rpc.match(/create or replace function public\.claim_daily_content_reward[\s\S]*?end\n\$\$;/i)?.[0]||'';
  assert.match(claim,/insert into public\.virtual_entitlements/);
  assert.match(claim,/insert into public\.player_content_claims/);
  assert.doesNotMatch(claim,/commit|rollback/i);
});

test('admin roles enforce editor and publisher separation',()=>{
  assert.match(schema,/role in \('viewer','editor','publisher','super_admin'\)/);
  assert.match(rpc,/v_role not in \('editor','publisher','super_admin'\).*editor_role_required/s);
  assert.match(rpc,/v_role not in \('publisher','super_admin'\).*publisher_role_required/s);
  assert.match(rpc,/upsert_status_not_allowed/);
  assert.match(rpc,/published_schedule_overlap/);
  assert.match(rpc,/version_conflict/);
});

test('audit is append-only and cancellation never deletes prior claims',()=>{
  assert.match(rpc,/insert into public\.admin_audit_log/g);
  assert.doesNotMatch(rpc,/delete from public\.(admin_audit_log|player_content_claims|virtual_entitlements)/i);
  assert.match(rpc,/set status='cancelled',ends_at=least\(ends_at,now\(\)\)/);
});

test('Edge gateway forwards caller auth and uses no privileged key',()=>{
  assert.match(edge,/Authorization: authorization/);
  assert.match(edge,/SUPABASE_ANON_KEY/);
  assert.doesNotMatch(edge,/service.role|SERVICE_ROLE|sb_secret_/i);
  assert.match(request,/action_not_allowed/);
  assert.match(request,/request_id_invalid/);
});

test('admin panel is staging-only and writes exclusively through RPC',()=>{
  assert.match(admin,/targetEnvironment!=='staging'/);
  assert.match(admin,/state\.client\.rpc/);
  assert.doesNotMatch(admin,/\.from\s*\(/);
  assert.doesNotMatch(admin,/localStorage|service_role|sb_secret_/i);
  assert.match(report,/attempt_count/);
  assert.match(report,/claim_count/);
});

test('local preview content adapter performs no network or RPC invocation',()=>{
  assert.match(adapter,/if\(state\.preview\)setItems\(mock\(\)\);else/);
  assert.match(adapter,/state\.preview\?\{claimed:true\}:await state\.invoke/);
  assert.doesNotMatch(adapter,/fetch\s*\(|XMLHttpRequest|\.rpc\s*\(/);
});

test('existing auth tap and economy contracts remain intact',()=>{
  assert.match(html,/async function authenticateTelegram\(\)/);
  assert.match(html,/db\.rpc\('marino_secure_rpc'/);
  assert.match(html,/rpc\('tap_coin', \{ p_taps: 1 \}\)/);
  assert.match(html,/function processState\(d\)/);
  const markup=html.replace(/<script(?:\s[^>]*)?>[\s\S]*?<\/script>/gi,'');
  const ids=[...markup.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
  assert.equal(ids.length,new Set(ids).size);
});
