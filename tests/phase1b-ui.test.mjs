import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const html = fs.readFileSync('public/index.html', 'utf8');
const js = fs.readFileSync('public/js/phase-1b.js', 'utf8');
const css = fs.readFileSync('public/styles/phase-1b.css', 'utf8');

test('combo and Empire Rush are presentation-only', () => {
  assert.doesNotMatch(js, /\brpc\s*\(|marino_secure_rpc|tap_coin|p_taps|processState/);
  assert.match(js, /\[10,25,50\]\.includes\(state\.combo\)/);
  assert.match(js, /setTimeout\(stopRush,6000\)/);
  assert.doesNotMatch(js, /S\.game|\.state\.(?:coin|chips|energy|tap)/);
});

test('effect pool is hard-capped at twelve reusable nodes', () => {
  assert.match(js, /const MAX_EFFECTS = 12/);
  assert.match(js, /i<MAX_EFFECTS/);
  assert.equal([...js.matchAll(/button\.appendChild\(fx\)/g)].length, 1);
  assert.match(js, /state\.effects\[|state\.effects\.filter/);
});

test('onboarding uses only versioned local UI state', () => {
  assert.match(js, /ONBOARDING_KEY = 'marino_onboarding_v1'/);
  assert.match(js, /localStorage\.setItem\(ONBOARDING_KEY,'1'\)/);
  assert.match(js, /restartOnboarding/);
  assert.doesNotMatch(js, /supabase|database|\brpc\s*\(/i);
});

test('disabled sound exits before creating an AudioContext', () => {
  assert.ok(js.indexOf("if(!soundEnabled()") < js.indexOf('state.audioContext=new Ctor()'));
  assert.match(js, /MAX_VOICES = 4/);
});

test('Lite and reduced-motion disable heavy effects', () => {
  assert.match(css, /\.quality-lite \.scene-ambient,\.quality-lite \.scene-reflection\{display:none\}/);
  assert.match(css, /\.quality-lite \.tap-fx\.coin\{display:none\}/);
  assert.match(css, /@media\(prefers-reduced-motion:reduce\)/);
  assert.match(css, /\.tap-fx\.coin\{display:none!important\}/);
});

test('protected Auth, RPC and tap economy contracts remain intact', () => {
  assert.match(html, /persistSession:\s*false/);
  assert.match(html, /db\.rpc\('marino_secure_rpc'/);
  assert.match(html, /rpc\('tap_coin', \{ p_taps: 1 \}\)/);
  assert.match(html, /if \(d\?\.state\) processState\(d\);\s*renderTop\(\);/);
});

test('new static markup IDs remain unique', () => {
  const markup = html.replace(/<script(?:\s[^>]*)?>[\s\S]*?<\/script>/gi, '');
  const ids = [...markup.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length);
});

test('premium home polish keeps the target viewport matrix and fallbacks', () => {
  assert.match(css, /@media\(max-height:700px\)/);
  assert.match(css, /@media\(max-height:600px\)/);
  assert.match(css, /@media\(min-width:430px\) and \(min-height:820px\)/);
  assert.match(css, /\.nav-bar\{left:10px!important;right:10px!important/);
  assert.match(css, /\.quality-lite \.tap-btn img\{animation:none/);
  assert.match(css, /@media\(prefers-reduced-motion:reduce\)[\s\S]*?\.tap-btn img\{animation:none!important\}/);
});
