import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const html = fs.readFileSync('public/index.html', 'utf8');
const previewSource = fs.readFileSync('public/js/local-preview.js', 'utf8');
const context = { window: {}, URLSearchParams };
vm.createContext(context);
vm.runInContext(previewSource, context);
const detect = context.window.MarinoLocalPreview.detect;

test('preview requires localhost and testmode=1 together', () => {
  assert.equal(detect({ hostname: 'localhost', search: '?testmode=1' }, null), true);
  assert.equal(detect({ hostname: '127.0.0.1', search: '?testmode=1' }, null), true);
  assert.equal(detect({ hostname: '::1', search: '?testmode=1' }, null), true);
  assert.equal(detect({ hostname: 'example.com', search: '?testmode=1' }, null), false);
  assert.equal(detect({ hostname: 'localhost', search: '' }, null), false);
  assert.equal(detect({ hostname: 'localhost', search: '?testmode=1' }, { initData: 'telegram-session' }), false);
});

test('preview blocks RPC and simulates tap and vault in memory', () => {
  assert.match(html, /if \(isLocalPreview\) throw new Error\('local_preview_rpc_blocked'\)/);
  assert.match(html, /if \(isLocalPreview\) \{\s*s\.coin \+= s\.tap;\s*s\.en = Math\.max\(0, s\.en - 1\);/);
  assert.match(html, /if \(isLocalPreview\) \{\s*const collected =/);
  assert.ok(html.indexOf('if (isLocalPreview) {\n        startLocalPreview();') < html.indexOf('if (!runtimeConfig || !db)'));
});

test('UI events are bound once for real and preview adapters', () => {
  assert.match(html, /let uiEventsBound = false;/);
  assert.match(html, /function bindUiEvents\(\) \{\s*if \(uiEventsBound\) return;\s*uiEventsBound = true;/);
  assert.equal([...html.matchAll(/function bindUiEvents\(/g)].length, 1);
});

test('Empire Hub is a sheet and home actions remain visible', () => {
  assert.doesNotMatch(html, /<details[^>]*id="empireHub"/);
  assert.match(html, /id="sheetEmpireHub" class="sheet-overlay"/);
  assert.match(html, /id="btnEmpireHub"/);
  assert.match(html, /class="quick-bar home-quick-actions"/);
  assert.equal([...html.matchAll(/id="btnOpenBoost"/g)].length, 1);
  assert.equal([...html.matchAll(/id="btnOpenAirdrop"/g)].length, 1);
});

test('protected Auth, RPC and economic contracts remain present', () => {
  assert.match(html, /async function authenticateTelegram\(\)/);
  assert.match(html, /db\.rpc\('marino_secure_rpc'/);
  assert.match(html, /rpc\('tap_coin', \{ p_taps: batchSize \}\)/);
  assert.match(html, /if \(d\?\.state\) processState\(d\);\s*renderTop\(\);/);
});

test('static DOM IDs remain unique', () => {
  const markup = html.replace(/<script(?:\s[^>]*)?>[\s\S]*?<\/script>/gi, '');
  const ids = [...markup.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length);
});
