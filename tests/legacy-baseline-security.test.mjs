import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const baseline = read('supabase/migrations/202607110001_legacy_gameplay_baseline.sql');
const secureGateway = read('supabase/migrations/202607120003_p0_secure_rpc.sql');
const adminGateway = read('supabase/migrations/202607120004_p0_admin_gateway.sql');
const privileges = read('supabase/migrations/202607120002_p0_function_privileges.sql');

const functionPattern = /CREATE FUNCTION\s+public\.([a-zA-Z0-9_]+)\s*\([\s\S]*?AS\s+(\$[a-zA-Z0-9_]*\$)[\s\S]*?\2\s*;/g;
const functionBlocks = [...baseline.matchAll(functionPattern)];
const withoutFunctionBodies = functionBlocks
  .slice()
  .reverse()
  .reduce((text, match) => `${text.slice(0, match.index)}${text.slice(match.index + match[0].length)}`, baseline);

test('baseline contains the complete canonical public object inventory', () => {
  assert.equal((baseline.match(/^CREATE TABLE public\./gm) ?? []).length, 24);
  assert.equal((baseline.match(/^CREATE SEQUENCE public\./gm) ?? []).length, 17);
  assert.equal(functionBlocks.length, 74);
  assert.equal((baseline.match(/^ALTER TABLE public\..* ENABLE ROW LEVEL SECURITY;/gm) ?? []).length, 24);
  assert.equal((baseline.match(/^CREATE POLICY\b/gm) ?? []).length, 0);
});

test('baseline contains no rows, managed schemas, owners, secrets or connection material', () => {
  assert.doesNotMatch(withoutFunctionBodies, /^\s*(?:COPY|INSERT\s+INTO)\b/im);
  assert.doesNotMatch(baseline, /\b(?:sb_secret_|service[_ -]?role(?:_key)?|jwt[_ -]?secret)\b/i);
  assert.doesNotMatch(baseline, /postgres(?:ql)?:\/\/|\bPGPASSWORD\s*=/i);
  assert.doesNotMatch(baseline, /^CREATE SCHEMA\s+(?:auth|storage)\b/im);
  assert.doesNotMatch(baseline, /^ALTER\s+.*\s+OWNER\s+TO\s+/im);
  assert.equal(fs.existsSync(path.join(root, 'marino-production-schema.sql')), false);
});

test('every SECURITY DEFINER has a fixed safe search path', () => {
  const definers = functionBlocks.filter((match) => /\bSECURITY\s+DEFINER\b/i.test(match[0]));
  assert.equal(definers.length, 64);
  for (const match of definers) {
    assert.match(match[0], /SET search_path = pg_catalog, public/i, match[1]);
  }
});

test('all baseline tables, sequences and functions are closed to client roles', () => {
  assert.match(baseline, /revoke all on table[\s\S]+from public, anon, authenticated;/i);
  assert.match(baseline, /revoke all on sequence[\s\S]+from public, anon, authenticated;/i);
  assert.equal((baseline.match(/^revoke all on function public\./gm) ?? []).length, 74);
});

test('secure and admin gateway legacy calls all resolve to baseline functions', () => {
  const definitions = new Set(functionBlocks.map((match) => match[1]));
  const allowedGatewayHelpers = new Set([
    '_marino_cipher_hint',
    'marino_current_telegram_id',
    'marino_admin_audit_log',
    'marino_idempotency_keys',
    'marino_secure_rpc',
    'marino_admin_rpc',
  ]);
  for (const source of [secureGateway, adminGateway]) {
    const calls = [...source.matchAll(/public\.([a-zA-Z0-9_]+)\s*\(/g)].map((match) => match[1]);
    const missing = [...new Set(calls)].filter((name) => !definitions.has(name) && !allowedGatewayHelpers.has(name));
    assert.deepEqual(missing, []);
  }
});

test('gateway calls use the exact canonical compatibility signatures', () => {
  assert.match(baseline, /-- FUNCTION: marino_get_leaderboard\(text, text, integer, integer\)/);
  assert.match(baseline, /-- FUNCTION: marino_place_sports_bet\(text, uuid, text, bigint\)/);
  assert.match(baseline, /-- FUNCTION: marino_play_horse_racing\(text, integer, integer\)/);
  assert.match(baseline, /-- FUNCTION: marino_play_poker\(text, integer\)/);
  assert.match(baseline, /-- FUNCTION: marino_admin_resolve_request\(text, integer, text, text\)/);
  assert.match(secureGateway, /marino_play_horse_racing\(v_telegram_id, v_bet::int,/);
  assert.match(secureGateway, /marino_play_poker\(v_telegram_id, v_bet::int\)/);
  assert.match(secureGateway, /marino_place_sports_bet\(v_telegram_id, \(p_payload->>'p_match_id'\)::uuid,/);
  assert.match(adminGateway, /\(p_payload->>'request_id'\)::integer/);
});

test('privilege boundary runs after its targets and has no redundant direct revokes', () => {
  for (const table of ['marino_daily_combo', 'marino_daily_cipher', 'marino_player_boosts', 'marino_wallets']) {
    assert.match(baseline, new RegExp(`CREATE TABLE public\\.${table}\\b`));
  }
  assert.match(privileges, /from pg_proc p/);
  assert.doesNotMatch(privileges, /revoke execute on function public\.marino_get_today_/i);
  assert.doesNotMatch(privileges, /revoke execute on function public\.marino_connect_wallet/i);
});
