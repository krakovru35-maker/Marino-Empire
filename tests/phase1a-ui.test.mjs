import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const html = fs.readFileSync('public/index.html', 'utf8');
const phaseJs = fs.readFileSync('public/js/phase-1a.js', 'utf8');
const phaseCss = fs.readFileSync('public/styles/phase-1a.css', 'utf8');

test('intro media is assigned only after the versioned first-run check', () => {
  const videoTag = html.match(/<video\s+id="introVid"[^>]*>/)?.[0] || '';
  assert.doesNotMatch(videoTag, /\ssrc=/);
  assert.match(videoTag, /data-src="\.\/assets\/intro\.mp4"/);
  assert.match(videoTag, /preload="none"/);
  const seenCheck = html.indexOf("localStorage.getItem('marino_intro_seen_v1')");
  const sourceAssignment = html.indexOf('v.src = videoSrc');
  assert.ok(seenCheck >= 0 && sourceAssignment > seenCheck);
});

test('intro finish is idempotent and supports ended plus maximum timeout', () => {
  assert.match(html, /let introFinished = false;/);
  assert.match(html, /function finishIntro\(\) \{\s*if \(introFinished\) return;/);
  assert.match(html, /clearTimeout\(introFinishTimer\)/);
  assert.match(html, /v\.onended = finishIntro;/);
  assert.match(html, /introFinishTimer = setTimeout\(finishIntro, introDuration \* 1000\)/);
  assert.match(phaseCss, /--intro-duration:\s*4\.5s/);
});

test('Empire Hub backdrop consumes outside interaction before closing', () => {
  assert.match(html, /id="empireHubBackdrop"[^>]*hidden/);
  assert.match(phaseJs, /backdrop\?\.addEventListener\('pointerdown'[\s\S]*?preventDefault\(\)[\s\S]*?stopPropagation\(\)[\s\S]*?closeEmpireHub\(\)/);
  assert.doesNotMatch(phaseJs, /backdrop\?\.addEventListener\('click'/);
  assert.doesNotMatch(phaseJs, /document\.addEventListener\('pointerdown'/);
});

test('Combo and Cipher controls retain unique stable IDs', () => {
  assert.equal([...html.matchAll(/id="btnDailyCombo"/g)].length, 1);
  assert.equal([...html.matchAll(/id="btnDailyCipher"/g)].length, 1);
});

test('quality and viewport use the same effective height helper', () => {
  assert.match(phaseJs, /function effectiveViewportHeight\(\)/);
  assert.match(phaseJs, /const compact = effectiveViewportHeight\(\) <= 568/);
  assert.match(phaseJs, /const height = effectiveViewportHeight\(\)/);
});

test('protected Auth, RPC and tap economy contracts remain present', () => {
  assert.match(html, /persistSession:\s*false/);
  assert.match(html, /db\.rpc\('marino_secure_rpc'/);
  assert.match(html, /rpc\('tap_coin', \{ p_taps: 1 \}\)/);
  assert.match(html, /if \(d\?\.state\) processState\(d\);\s*renderTop\(\);/);
});
