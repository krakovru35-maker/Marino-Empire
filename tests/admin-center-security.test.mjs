import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = path => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const html=read('public/index.html'),admin=read('public/js/admin-center.js'),ann=read('public/js/live-announcements.js');
const css=read('public/styles/admin-center.css')+read('public/styles/live-announcements.css');
const canonical=read('supabase/migrations/202607150008_canonical_admin_center.sql');
const gateway=read('supabase/migrations/202607150009_admin_management_gateway.sql');
const announcements=read('supabase/migrations/202607150010_live_announcements.sql');

test('normal players never receive a visible management entry before server admin_me',()=>{
  assert.match(html,/id="btnAdminCenter"[^>]*hidden/);
  assert.match(admin,/entry\.hidden=true;try\{const me=await bridge\(\)\.me\(\)/);
  assert.match(admin,/if\(!me\?\.is_admin\)return;entry\.hidden=false/);
  assert.doesNotMatch(admin,/(localStorage|sessionStorage).*admin/i);
});

test('canonical authority protects the single immutable owner and service-role bootstrap',()=>{
  assert.match(canonical,/role in \('super_admin','admin'\)/);
  assert.match(canonical,/create unique index marino_single_owner_idx[\s\S]*where is_owner/);
  assert.match(canonical,/owner_is_immutable[\s\S]*before update or delete/);
  assert.match(canonical,/marino_identity_links[\s\S]*last_verified_at>now\(\)-interval '24 hours'/);
  assert.match(canonical,/revoke all on function public\.marino_bootstrap_owner\(text\) from public,anon,authenticated/);
  assert.match(canonical,/grant execute on function public\.marino_bootstrap_owner\(text\) to service_role/);
  assert.doesNotMatch(canonical,/OWNER_TELEGRAM_ID_BURAYA|p_owner_telegram_id\s*:=/);
});

test('admin permissions, critical re-verification, idempotency and audit are server-side',()=>{
  assert.match(canonical,/\('admins\.manage',false/);
  assert.match(gateway,/p_permission='admins\.manage' and not v_member\.is_owner/);
  assert.match(gateway,/last_verified_at>now\(\)-interval '5 minutes'/);
  assert.match(gateway,/marino_admin_request_keys[\s\S]*on conflict do nothing/);
  assert.match(gateway,/marino_admin_audit_details[\s\S]*'succeeded'/);
  assert.match(gateway,/abs\(v_coin_delta\)>10000000/);
  assert.match(gateway,/negative_balance_not_allowed/);
});

test('announcement delivery is targeted, sanitized and direct writes stay closed',()=>{
  assert.match(announcements,/marino_announcement_is_targeted\(a\.id,v_user\)/);
  assert.match(announcements,/p_payload \?\| array\['auth_user_id','telegram_id','target_rules','status'\]/);
  assert.match(announcements,/action_type text[\s\S]*check\(action_type in \('none','event','combo','cipher','rewards','chat','store','update','dismiss'\)\)/);
  assert.match(announcements,/revoke all on table public\.%I from public,anon,authenticated/);
  assert.match(announcements,/marino_announcement_signals[\s\S]*signal in \('refresh','stop'\)/);
  assert.doesNotMatch(announcements,/https?:\/\/|javascript:/i);
});

test('announcement UI uses textContent and respects ready, safe-area and reduced motion',()=>{
  assert.match(ann,/announcementTitle'\)\.textContent=item\.title/);
  assert.match(ann,/announcementMessage'\)\.textContent=item\.message/);
  assert.doesNotMatch(ann,/innerHTML|insertAdjacentHTML|outerHTML/);
  assert.match(ann,/dataset\.appState!=='ready'/);
  assert.match(css,/env\(safe-area-inset-bottom\)/);
  assert.match(css,/@media\(prefers-reduced-motion:reduce\)/);
  assert.match(css,/z-index:760/);
});

test('management center exposes the requested permission-gated module map',()=>{
  for(const module of ['overview','users','content','events','rewards','tasks','casino','social','announcements','notifications','settings','audit','admins']) assert.match(admin,new RegExp(`'${module}'`));
  assert.match(admin,/criticalPayload[\s\S]*confirmed:true/);
  assert.match(admin,/crypto\.randomUUID\(\)/);
});
