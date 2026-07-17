import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = file => fs.readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const html = read('public/index.html');
const center = read('public/js/admin-center.js');
const operations = read('public/js/admin-operations.js');
const adminCss = read('public/styles/admin-center.css');
const migration = read('supabase/migrations/202607180004_activate_admin_modules.sql');

test('auto tap performs bounded server-authoritative ticks without synthetic pointer events', () => {
  assert.match(html, /const AUTO_TAP_INTERVAL_MS = 15000/);
  assert.match(html, /async function performAutoTapTick/);
  assert.match(html, /rpc\('tap_coin', \{ p_taps: 1 \}\)/);
  assert.match(html, /document\.visibilityState === 'hidden'/);
  assert.match(html, /autoTapInFlight/);
  assert.match(html, /syncAutoTapLoop\(\)/);
  assert.doesNotMatch(html, /dispatchEvent\(new (?:Pointer|Mouse)Event/);
});

test('claim mining has a visible home shortcut and remains behind the authenticated bridge', () => {
  assert.match(html, /id="btnOpenClaimMining"/);
  assert.match(html, /showTab\('store'\)/);
  assert.match(html, /MarinoClaimMining\?\.sync/);
  assert.match(html, /marino_claim_mining_rpc/);
});

test('remaining admin tabs render operational modules and mobile navigation is tappable', () => {
  for (const name of ['renderCasino', 'renderSocial', 'renderNotifications', 'renderSettings']) {
    assert.match(center, new RegExp(name));
    assert.match(operations, new RegExp(`function ${name}`));
  }
  assert.match(center, /modules:\(\.\.\.args\)=>bridge\(\)\.modules/);
  assert.match(center, /broadcast:\(\.\.\.args\)=>bridge\(\)\.broadcast/);
  assert.doesNotMatch(center, /function criticalPayload\([^)]*\)\{if\(!confirm/);
  assert.match(adminCss, /\.admin-nav button\{flex:0 0 auto/);
  assert.match(adminCss, /touch-action:manipulation/);
});

test('admin modules RPC is fixed-path, role-gated, idempotent and client-role constrained', () => {
  assert.match(migration, /marino_admin_modules_rpc[\s\S]*security definer[\s\S]*set search_path = pg_catalog, public/i);
  assert.match(migration, /marino_admin_require\(v_permission, false\)/i);
  assert.match(migration, /marino_admin_request_keys/i);
  assert.match(migration, /invalid_admin_request/i);
  assert.match(migration, /revoke all on function public\.marino_admin_modules_rpc\(text,jsonb,uuid\) from public, anon/i);
  assert.match(migration, /grant execute on function public\.marino_admin_modules_rpc\(text,jsonb,uuid\) to authenticated/i);
  assert.match(migration, /settings_update', 'settings\.manage', false/i);
});

test('casino and social mutations validate bounded values and write audit records', () => {
  assert.match(migration, /v_min_bet < 1 or v_min_bet > 1000000/i);
  assert.match(migration, /v_max_bet < v_min_bet or v_max_bet > 100000000/i);
  assert.match(migration, /v_social_code !~ '\^\[A-F0-9\]\{3\}\$'/i);
  assert.match(migration, /insert into public\.marino_admin_audit_details/i);
});
