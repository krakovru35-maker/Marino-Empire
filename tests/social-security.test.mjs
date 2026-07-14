import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration = fs.readFileSync('supabase/migrations/202607140006_social_chat_and_gifts.sql', 'utf8');
const cryptoFix = fs.readFileSync('supabase/migrations/202607140007_social_pgcrypto_qualification.sql', 'utf8');
const html = fs.readFileSync('public/index.html', 'utf8');
const js = fs.readFileSync('public/js/social-hub.js', 'utf8');
const css = fs.readFileSync('public/styles/social-hub.css', 'utf8');
const moderationHtml = fs.readFileSync('public/moderation.html', 'utf8');
const moderationJs = fs.readFileSync('public/js/admin/social-moderation.js', 'utf8');

test('social schema is deny-by-default and RPC-only', () => {
  for (const table of ['marino_social_profiles','marino_chat_messages','marino_chat_blocks','marino_chat_reports','marino_friend_requests','marino_friendships','marino_gift_catalog','marino_gift_transactions','marino_social_stats']) {
    assert.match(migration, new RegExp(`'${table}'`));
  }
  assert.match(migration, /enable row level security/);
  assert.match(migration, /revoke all on table public\.%I from public, anon, authenticated/);
  assert.match(migration, /grant execute on function public\.marino_social_rpc\(text,jsonb,uuid\) to authenticated/);
  assert.doesNotMatch(migration, /grant\s+(select|insert|update|delete).*authenticated/i);
});

test('security definer functions use fixed search paths and caller identity', () => {
  const definers = [...migration.matchAll(/create or replace function\s+([^\s(]+)[\s\S]*?security definer[\s\S]*?set search_path = pg_catalog, public/gi)];
  assert.ok(definers.length >= 9);
  assert.match(migration, /v_auth uuid := auth\.uid\(\)/);
  assert.match(migration, /caller_identity_or_price_not_allowed/);
  assert.doesNotMatch(migration, /p_telegram_id\s+(text|bigint|integer)/i);
});

test('public chat payload is anonymous and contains only social identity', () => {
  const historyPayload = migration.match(/jsonb_build_object\('id',m\.id,'alias',sp\.public_alias[\s\S]*?'own',m\.sender_auth_user_id=v_user\.auth_user_id\)/)?.[0] || '';
  assert.match(historyPayload, /social_code/);
  assert.doesNotMatch(historyPayload, /telegram_id|auth_user_id'|display_name|email|player_id/i);
  assert.match(migration, /gen_random_bytes\(2\)/);
  assert.match(migration, /public_alias text not null check/);
});

test('server filter covers contact channels, unicode, digits and own identity', () => {
  for (const marker of ['normalize(p_text, NFKC)', 't\\.me', 'whatsapp', 'instagram', 'discord', 'snapchat', 'facebook', 'twitter', 'telegram_username', 'display_name', 'iletişim bilgisi gizlendi', "char_length(p_text) > 160"]) {
    assert.ok(migration.includes(marker), `missing filter marker: ${marker}`);
  }
  assert.match(migration, /translate\(v_text, U&/);
  assert.match(migration, /\[\^0-9\].*\{7,/s);
  assert.doesNotMatch(migration, /raw_body|unfiltered|original_message/i);
});

test('gift transaction is server-priced, locked, idempotent and coin sink only', () => {
  assert.match(migration, /where id=v_user\.player_id for update/);
  assert.match(migration, /marino_coin=marino_coin-v_gift\.coin_price/);
  assert.match(migration, /unique \(sender_auth_user_id, request_id\)/);
  assert.match(migration, /v_day_total >= 10/);
  assert.match(migration, /v_pair_total >= 3/);
  assert.match(migration, /caller_identity_or_price_not_allowed/);
  assert.doesNotMatch(migration, /recipient.*marino_coin\s*=|marino_coin\s*=.*recipient/i);
});

test('pgcrypto calls are explicitly qualified without widening search_path', () => {
  assert.match(cryptoFix, /extensions\.gen_random_bytes\(2\)/);
  assert.equal((cryptoFix.match(/extensions\.digest\(/g) || []).length, 2);
  assert.doesNotMatch(cryptoFix, /search_path\s*=.*extensions/i);
  assert.match(cryptoFix, /revoke all on function public\.marino_gift_send/);
});

test('social UI keeps untrusted messages out of innerHTML', () => {
  assert.match(html, /styles\/social-hub\.css/);
  assert.match(html, /js\/social-hub\.js/);
  assert.match(js, /body\.textContent = String\(message\.body/);
  assert.doesNotMatch(js, /message\.body[^\n]*innerHTML|innerHTML[^\n]*message\.body/);
  assert.match(js, /crypto\.randomUUID\(\)/);
  assert.match(js, /3000 \* Math\.max\(1, state\.failures\)/);
});

test('mobile social layout includes keyboard-safe scroll and safe area', () => {
  assert.match(css, /env\(safe-area-inset-bottom/);
  assert.match(css, /min-height:0/);
  assert.match(css, /overflow-y:auto/);
  assert.match(css, /@media\(max-width:350px\),\(max-height:620px\)/);
  for (const tab of ['general','league','friends','gifts']) assert.match(html, new RegExp(`data-social-tab="${tab}"`));
});

test('moderation console trusts only the server role gateway', () => {
  assert.match(moderationHtml, /Sosyal Moderasyon/);
  assert.match(moderationJs, /rpc\('marino_social_admin_rpc'/);
  assert.doesNotMatch(moderationJs, /localStorage|sessionStorage|service_role|telegram_id/);
  assert.match(moderationJs, /text\.textContent = report\.filtered_body/);
  assert.match(migration, /v_role not in \('operator','security_admin'\)/);
  assert.match(migration, /insert into public\.marino_admin_audit_log/);
});
