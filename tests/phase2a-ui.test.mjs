import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const html = fs.readFileSync('public/index.html', 'utf8');
const js = fs.readFileSync('public/js/phase-2a.js', 'utf8');
const css = fs.readFileSync('public/styles/phase-2a.css', 'utf8');

test('level thresholds select the three Living Empire tiers', () => {
  assert.match(js, /value >= 30 \? 3 : value >= 10 \? 2 : 1/);
  const selectTier = progression => {
    const level = Number(progression.level || 0);
    const buildingLevel = Number(progression.buildingLevel || 0);
    const value = level > 0 ? level : buildingLevel;
    return value >= 30 ? 3 : value >= 10 ? 2 : 1;
  };
  assert.equal(selectTier({ level: 1 }), 1);
  assert.equal(selectTier({ level: 10 }), 2);
  assert.equal(selectTier({ level: 30 }), 3);
});

test('scene selection is presentation-only and cannot mutate economy state', () => {
  assert.doesNotMatch(js, /\bS\.game|\.coin\s*[+\-=]|\.chips\s*[+\-=]|\.energy\s*[+\-=]|\brpc\s*\(|processState|tap_coin|p_taps/);
  assert.match(js, /home\.dataset\.empireTier/);
});

test('collect presentation starts only after successful collect handling', () => {
  const realSuccess = html.indexOf("processState(d); toast('Kasa toplandı!");
  const realEffect = html.indexOf('MarinoPhase2A?.collectSuccess?.', realSuccess);
  const catchBranch = html.indexOf('} catch (e) { toast(e.message); au.fail(); }', realSuccess);
  assert.ok(realSuccess > -1 && realEffect > realSuccess && realEffect < catchBranch);
  assert.doesNotMatch(html.slice(catchBranch, catchBranch + 70), /collectSuccess/);
  assert.match(js, /notificationOccurred\('success'\)/);
});

test('local preview tier control is gated and memory-only', () => {
  assert.match(js, /MarinoLocalPreview\?\.detect/);
  assert.match(js, /if \(!isLocalPreview\(\) \|\| document\.querySelector\('#empireTierControl'\)\) return/);
  assert.match(js, /state\.previewTier = Number\(button\.dataset\.tier\)/);
  assert.doesNotMatch(js, /localStorage|sessionStorage|fetch\(|XMLHttpRequest|supabase/);
});

test('Lite and reduced-motion disable heavy environment effects', () => {
  assert.match(css, /\.quality-lite \.empire-crowd,\.quality-lite \.empire-dust\{display:none\}/);
  assert.match(css, /@media\(prefers-reduced-motion:reduce\)/);
  assert.match(css, /\.empire-dust,\.empire-crowd\{display:none!important\}/);
  assert.match(css, /\.collect-flight\{display:none!important\}/);
});

test('protected Auth, RPC and economy contracts stay intact', () => {
  assert.match(html, /function authenticateTelegram\(/);
  assert.match(html, /db\.rpc\('marino_secure_rpc'/);
  assert.match(html, /rpc\('tap_coin', \{ p_taps: batchSize \}\)/);
  assert.match(html, /if \(d\?\.state\) processState\(d\);\s*renderTop\(\);/);
  assert.match(html, /rpc\('collect_income', \{ p_telegram_id: String\(S\.user\.id\), p_request_id: uid\(\) \}\)/);
});

test('static DOM IDs remain unique', () => {
  const markup = html.replace(/<script(?:\s[^>]*)?>[\s\S]*?<\/script>/gi, '');
  const ids = [...markup.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length);
});

test('environment DOM stays bounded and ignores pointer input', () => {
  assert.equal([...html.matchAll(/class="empire-(?:depth|neon-bank|crowd|slot-lights|dust)/g)].length, 5);
  assert.match(css, /\.empire-depth,\.empire-neon-bank,\.empire-crowd,\.empire-slot-lights,\.empire-dust\{[^}]*pointer-events:none/);
  assert.doesNotMatch(js, /setInterval/);
});
