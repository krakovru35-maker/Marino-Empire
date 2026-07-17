import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const claim = fs.readFileSync('public/js/loyalty-center.js','utf8');
const claimCss = fs.readFileSync('public/styles/loyalty-center.css','utf8');
const polish = fs.readFileSync('public/styles/mobile-boot-polish.css','utf8');
const admin = fs.readFileSync('public/js/admin-operations.js','utf8');
const migration = fs.readFileSync('supabase/migrations/202607180006_claim_mining_equipment_catalog.sql','utf8');

test('bound site usernames are player immutable and admin-correctable only',()=>{
  assert.match(claim,/site_username_admin_only/);
  assert.match(claim,/Yalnız yönetici düzeltebilir/);
  assert.doesNotMatch(claim,/>Güncelle<\/button>/);
  assert.match(migration,/exists\(select 1 from public\.marino_site_accounts where player_id=v_player\.id\)[\s\S]*site_username_admin_only/i);
  assert.match(migration,/site_account_update[\s\S]*marino_admin_require\('rewards\.manage',false\)/i);
  assert.match(admin,/Site Kullanıcı Adını Düzelt/);
  assert.match(admin,/site_account_update/);
});

test('mining equipment is server-priced, progress-gated and idempotent',()=>{
  assert.match(migration,/create table if not exists public\.marino_claim_equipment_catalog/i);
  assert.match(migration,/create table if not exists public\.marino_claim_player_equipment/i);
  assert.match(migration,/buy_mining_item[\s\S]*required_lifetime_mined[\s\S]*insufficient_claim_coin/i);
  assert.match(migration,/marino_idempotency_keys/);
  assert.match(claim,/data-claim-equipment/);
  assert.match(claimCss,/claim-equipment-list/);
  assert.doesNotMatch(claim,/localStorage|sessionStorage|fetch\s*\(|\.rpc\(/);
});

test('reward price list is catalog driven and editable through reviewed admin gateway',()=>{
  for(const code of ['free_spin_1','free_spin_3','free_spin_5','free_bet_1','free_bet_3'])assert.match(migration,new RegExp(code));
  assert.match(migration,/reward_catalog_update/);
  assert.match(admin,/Claim Coin Fiyat Listesi/);
  assert.match(admin,/reward_catalog_update/);
  assert.match(claim,/rewardRows\(username,balance\)/);
  assert.match(claim,/catalog_code/);
});

test('activity rewards require trusted verification and exclude coercive balance penalties',()=>{
  for(const key of ['agent_connection','account_2fa','daily_safe_checkin','seven_day_checkin'])assert.match(migration,new RegExp(key));
  assert.match(migration,/activity_task_verify/);
  assert.match(migration,/task_not_verified/);
  assert.match(migration,/verified_at/);
  assert.doesNotMatch(migration,/inactivity|withdrawal|deposit|wager|bahis|yatırım|çekim|claim_coin\s*=\s*claim_coin\s*-\s*2/i);
  assert.match(admin,/Görev Doğrula/);
});

test('new private tables are deny by default and RPCs retain fixed search paths',()=>{
  assert.match(migration,/enable row level security/g);
  assert.match(migration,/using \(false\) with check \(false\)/i);
  assert.match(migration,/revoke all on table public\.%I from public,anon,authenticated/i);
  assert.match(migration,/security definer\s+set search_path = pg_catalog, public/i);
  assert.equal([...migration.matchAll(/security definer\s+set search_path = pg_catalog, public/ig)].length,2);
  assert.match(migration,/revoke all on function public\.marino_claim_mining_rpc\(text,jsonb,uuid\) from public,anon/i);
});

test('critical toast stays below the Telegram safe header',()=>{
  assert.match(polish,/\.toast \{[\s\S]*position: fixed !important/);
  assert.match(polish,/top: max\(calc\(var\(--safeT\) \+ 12px\), 72px\) !important/);
  assert.match(polish,/max-width: calc\(100vw - 28px\)/);
});

test('local preview boots mining after deferred module load',()=>{
  assert.match(claim,/addEventListener\('marino:app-ready', \(\) => setTimeout\(load, 0\)\)/);
  assert.match(claim,/if \(bridge\(\)\?\.preview\) setTimeout\(load, 0\)/);
  assert.match(claim,/#btnOpenClaimMining[\s\S]*\.nav-btn\[data-tab="store"\]/);
});
