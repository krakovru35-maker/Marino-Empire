import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const migrationPath = new URL(
  '../supabase/migrations/202607140004_legacy_function_schema_reconciliation.sql',
  import.meta.url,
);
const migration = fs.readFileSync(migrationPath, 'utf8');
const secureGateway = fs.readFileSync(
  new URL('../supabase/migrations/202607120003_p0_secure_rpc.sql', import.meta.url),
  'utf8',
);
const adminGateway = fs.readFileSync(
  new URL('../supabase/migrations/202607120004_p0_admin_gateway.sql', import.meta.url),
  'utf8',
);

const retired = [
  '_marino_refresh_energy',
  '_marino_seed_store',
  '_marino_state',
  'marino_recalculate_income',
  'marino_bootstrap',
  'sync_leaderboard',
  '_marino_seed_buildings',
  '_marino_recalc_income',
  'marino_touch_state',
  'marino_sync_player',
  'marino_income_per_hour',
  'marino_state',
  'marino_upgrades',
  'get_game_state',
  'marino_upgrades_json',
];

test('all drifted legacy functions are retained as explicit fail-closed signatures', () => {
  for (const name of retired) {
    assert.match(migration, new RegExp(`create or replace function public\\.${name.replace(/^_/, '\\_') }\\(`, 'i'));
  }
  assert.equal((migration.match(/legacy_function_retired/g) || []).length, retired.length);
});

test('retired and reconciled functions have explicit client privilege revokes', () => {
  for (const name of [...retired, 'marino_admin_resolve_request', 'marino_play_poker']) {
    assert.match(
      migration,
      new RegExp(`revoke all on function public\\.${name.replace(/^_/, '\\_')}\\([^;]+from public, anon, authenticated;`, 'i'),
    );
  }
});

test('admin reconciliation uses canonical reward request columns', () => {
  assert.match(migration, /set status = p_action,\s*reviewed_at = now\(\),\s*is_read = false/i);
  assert.doesNotMatch(migration, /set status = p_action,\s*updated_at = now\(\)/i);
});

test('poker keeps the live function body and removes static temp relation linting', () => {
  assert.match(migration, /pg_get_functiondef\('public\.marino_play_poker\(text,integer\)'::regprocedure\)/);
  assert.match(migration, /pg_temp\.tmp_poker_matchups/);
  assert.match(migration, /v_matchups_empty/);
  assert.doesNotMatch(migration, /create table public\.tmp_poker_matchups/i);
});

test('hotfix contains no user-row DML or table schema fabrication', () => {
  const withoutFunctionBodies = migration
    .replace(/as \$\$[\s\S]*?\$\$;/gi, '')
    .replace(/do \$reconcile_poker\$[\s\S]*?\$reconcile_poker\$;/gi, '');
  assert.doesNotMatch(withoutFunctionBodies, /\b(?:insert|update|delete|truncate)\b/i);
  assert.doesNotMatch(migration, /\b(?:create|alter)\s+table\b/i);
});

test('reviewed gateways do not call any retired legacy function', () => {
  const combined = `${secureGateway}\n${adminGateway}`;
  for (const name of retired) {
    assert.doesNotMatch(combined, new RegExp(`public\\.${name}\\(`, 'i'));
  }
  assert.match(secureGateway, /public\.marino_play_poker\(/i);
  assert.match(adminGateway, /public\.marino_admin_resolve_request\(/i);
});
