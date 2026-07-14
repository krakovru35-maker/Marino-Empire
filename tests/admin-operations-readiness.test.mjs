import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=file=>fs.readFileSync(new URL(`../${file}`,import.meta.url),'utf8');
const html=read('public/index.html');
const center=read('public/js/admin-center.js');
const operations=read('public/js/admin-operations.js');
const announcements=read('public/js/live-announcements.js');
const migration=read('supabase/migrations/202607150011_admin_operations_and_tasks.sql');
const delivery=read('supabase/migrations/202607150012_announcement_delivery_hardening.sql');
const cleanup=read('supabase/migrations/202607150013_remove_proven_unused_tables.sql');

test('admin center entry remains reusable after close',()=>{
  assert.doesNotMatch(center,/addEventListener\('click',openCenter,\{once:true\}\)/);
  assert.match(center,/dataset\.adminBound/);
  assert.match(center,/addEventListener\('click',openCenter\)/);
});

test('content, event and task modules render functional operations',()=>{
  assert.match(center,/renderContent/);
  assert.match(center,/renderEvents/);
  assert.match(center,/renderTasks/);
  assert.match(operations,/admin_upsert_daily_content/);
  assert.match(operations,/event_upsert/);
  assert.match(operations,/task_upsert/);
  assert.match(html,/admin-operations\.js/);
});

test('admin bridges are allowlisted and session checked',()=>{
  assert.match(html,/CONTENT_ADMIN_RPCS = new Set/);
  assert.match(html,/content_admin_action_not_allowed/);
  assert.match(html,/marino_operations_admin_rpc/);
  assert.match(html,/ensureFreshSession\(\)/);
});

test('task catalogue and claims use canonical server definitions',()=>{
  assert.match(migration,/create or replace function public\.marino_task_state\(\)/i);
  assert.match(migration,/Görev aktif değil\./);
  assert.match(migration,/update public\.marino_tasks set task_key = lower\(task_key\)/i);
  assert.match(html,/db\.rpc\('marino_task_state'\)/);
  assert.match(html,/S\.taskCatalog\.length/);
  assert.doesNotMatch(html,/const tId = `L\$\{l\}_G1`/);
});

test('announcement form supports immediate publish and target rules',()=>{
  assert.match(announcements,/publishNow\.checked=true/);
  assert.match(announcements,/announcement_publish/);
  assert.match(announcements,/rules\.language/);
  assert.match(announcements,/rules\.auth_user_id/);
  assert.match(delivery,/a\.status in \('active','scheduled'\)/);
  assert.match(delivery,/coalesce\(a\.repeat_interval_minutes,60\)/);
});

test('cleanup is empty-only, restrict-only and preserves nonempty task claims',()=>{
  assert.match(cleanup,/exists\(select 1 from public\.marino_in_game_notifications limit 1\)/i);
  assert.match(cleanup,/drop table public\.marino_in_game_notifications restrict/i);
  assert.doesNotMatch(cleanup,/cascade/i);
  assert.doesNotMatch(cleanup,/marino_task_claims/i);
});

test('operations RPC is fixed search path and role-gated',()=>{
  assert.match(migration,/marino_operations_admin_rpc[\s\S]*security definer[\s\S]*set search_path = pg_catalog, public/i);
  assert.match(migration,/marino_admin_require\(v_policy\.permission_key,v_policy\.critical\)/);
  assert.match(migration,/revoke all on function public\.marino_operations_admin_rpc\(text,jsonb,uuid\) from public,anon/i);
  assert.match(migration,/grant execute on function public\.marino_operations_admin_rpc\(text,jsonb,uuid\) to authenticated/i);
});
