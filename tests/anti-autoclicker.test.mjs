import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('public/index.html', 'utf8');
const migration = fs.readFileSync('supabase/migrations/202607150014_anti_autoclicker_tap_limits.sql', 'utf8');

test('frontend tap guard drops scripted and impossible tap bursts before RPC', () => {
  assert.match(html, /function isTapEventAllowed\(event\)/);
  assert.match(html, /event && event\.isTrusted === false/);
  assert.match(html, /tapGuardUntil = now \+ TAP_GUARD\.cooldownMs/);
  assert.match(html, /queuedTapCount \+ tapInFlightCount >= TAP_GUARD\.queueLimit/);
  assert.match(html, /minPointerIntervalMs: 38/);
  assert.match(html, /maxBatchSize: 10/);
  assert.match(html, /flushDelayMs: 140/);
  assert.match(html, /if \(!isTapEventAllowed\(e\)\) return;[\s\S]*handleTap\(e\);/);
  assert.match(html, /const d = await rpc\('tap_coin', \{ p_taps: batchSize \}\)/);
  assert.match(html, /Math\.min\(TAP_GUARD\.maxBatchSize, queuedTapCount, availableEnergy\)/);
});

test('server migration adds deny-by-default tap rate-limit state', () => {
  assert.match(migration, /create table if not exists public\.marino_tap_rate_limits/);
  assert.match(migration, /alter table public\.marino_tap_rate_limits enable row level security/);
  assert.match(migration, /revoke all on table public\.marino_tap_rate_limits from public/);
  assert.match(migration, /revoke all on table public\.marino_tap_rate_limits from anon/);
  assert.match(migration, /revoke all on table public\.marino_tap_rate_limits from authenticated/);
  assert.match(migration, /taps_in_window integer not null default 0 check/);
  assert.match(migration, /blocked_until timestamptz/);
});

test('tap_coin replacement validates identity, batch size, locks rows, and emits rate-limit errors', () => {
  assert.match(migration, /create or replace function public\.tap_coin\(p_telegram_id text, p_taps integer default 1\) returns jsonb/);
  assert.match(migration, /security definer/);
  assert.match(migration, /set search_path = pg_catalog, public/);
  assert.match(migration, /p_telegram_id !~ '\^\[0-9\]\{3,32\}\$'/);
  assert.match(migration, /p_taps is null or p_taps < 1 or p_taps > v_max_batch_taps/);
  assert.match(migration, /v_max_batch_taps integer := 10/);
  assert.match(migration, /v_max_window_taps integer := 80/);
  assert.match(migration, /for update/);
  assert.match(migration, /raise exception 'tap_rate_limited' using errcode = 'P0001'/);
  assert.match(migration, /revoke all on function public\.tap_coin\(text, integer\) from authenticated/);
});
