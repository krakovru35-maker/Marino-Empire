import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = file => fs.readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');

const html = read('public/index.html');
const claimJs = read('public/js/claim-mining.js');
const claimCss = read('public/styles/claim-mining.css');
const adminCenter = read('public/js/admin-center.js');
const adminOps = read('public/js/admin-operations.js');
const migration = read('supabase/migrations/202607180003_claim_coin_mining_rewards.sql');

test('Claim Coin UI is loaded as a dedicated Store module', () => {
  assert.match(html, /styles\/claim-mining\.css/);
  assert.match(html, /js\/claim-mining\.js/);
  assert.match(claimJs, /claimMiningMount/);
  assert.match(claimJs, /bind_site_username/);
  assert.match(claimJs, /mine_claim_coin/);
  assert.match(claimJs, /create_reward_claim/);
  assert.match(claimJs, /\^\[A-Za-z0-9_\.-\]\{3,32\}\$/);
  assert.match(claimCss, /claim-mining-card/);
  assert.match(claimCss, /claim-username-overlay/);
});

test('frontend claim flow stays behind authenticated bridge and does not mint offline value', () => {
  assert.match(html, /window\.MarinoClaimBridge/);
  assert.match(html, /ensureFreshSession\(\)/);
  assert.match(html, /marino_claim_mining_rpc/);
  assert.match(html, /delete clean\.telegram_id/);
  assert.match(html, /delete clean\.player_id/);
  assert.doesNotMatch(claimJs, /localStorage|sessionStorage|XMLHttpRequest|fetch\s*\(/);
  assert.doesNotMatch(claimJs, /\.rpc\(/);
  assert.doesNotMatch(claimJs, /telegram_id|player_id|auth_user_id/);
});

test('admin rewards panel uses reviewed gateway without critical reason prompts', () => {
  assert.match(adminCenter, /claimAdmin/);
  assert.match(html, /marino_claim_admin_rpc/);
  assert.match(adminCenter, /renderRewards/);
  assert.match(adminOps, /renderRewards/);
  assert.match(adminOps, /claims_list/);
  assert.match(adminOps, /claim_set_status/);
  assert.match(adminOps, /approved/);
  assert.match(adminOps, /fulfilled/);
  const renderRewardsBody = adminOps.match(/function renderRewards[\s\S]*?window\.MarinoAdminOperations/)[0];
  assert.doesNotMatch(renderRewardsBody, /criticalPayload/);
});

test('claim migration creates private tables, permission catalog and authenticated RPCs', () => {
  assert.match(migration, /create table if not exists public\.marino_site_accounts/i);
  assert.match(migration, /create table if not exists public\.marino_claim_coin_wallets/i);
  assert.match(migration, /create table if not exists public\.marino_reward_claim_requests/i);
  assert.match(migration, /marino_admin_permission_catalog[\s\S]*rewards\.view[\s\S]*rewards\.manage/i);
  assert.match(migration, /enable row level security/i);
  assert.match(migration, /using \(false\) with check \(false\)/i);
  assert.match(migration, /revoke all on table public\.marino_site_accounts from public, anon, authenticated/i);
  assert.match(migration, /revoke all on function public\.marino_claim_mining_rpc\(text,jsonb,uuid\) from public, anon/i);
  assert.match(migration, /grant execute on function public\.marino_claim_mining_rpc\(text,jsonb,uuid\) to authenticated/i);
});

test('player RPC derives identity from auth session and enforces slow mining economics', () => {
  assert.match(migration, /auth\.uid\(\)/);
  assert.match(migration, /join public\.marino_players p using \(telegram_id\)/i);
  assert.match(migration, /caller_identity_not_allowed/);
  assert.match(migration, /marino_idempotency_keys/);
  assert.match(migration, /interval '20 minutes'/);
  assert.match(migration, /v_wallet\.mined_today >= 18/);
  assert.match(migration, /site_username_required/);
  assert.match(migration, /free_spin[\s\S]*30/);
  assert.match(migration, /free_bet[\s\S]*45/);
  assert.doesNotMatch(migration, /insert\s+into\s+public\.(marino_free|free_spin|free_bet|marino_user_rewards)/i);
});

test('admin claim gateway is role-gated, audited and fixed search path', () => {
  assert.match(migration, /marino_claim_admin_rpc[\s\S]*security definer[\s\S]*set search_path = pg_catalog, public/i);
  assert.match(migration, /marino_admin_require\('rewards\.view', false\)/);
  assert.match(migration, /marino_admin_require\('rewards\.manage', false\)/);
  assert.match(migration, /insert into public\.marino_admin_audit_details/i);
  assert.match(migration, /claim_panel_action/);
  assert.match(migration, /revoke all on function public\.marino_claim_admin_rpc\(text,jsonb,uuid\) from public, anon/i);
  assert.match(migration, /grant execute on function public\.marino_claim_admin_rpc\(text,jsonb,uuid\) to authenticated/i);
});
