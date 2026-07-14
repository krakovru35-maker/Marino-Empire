import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const html = fs.readFileSync('public/index.html', 'utf8');
const phaseJs = fs.readFileSync('public/js/phase-1a.js', 'utf8');
const polishCss = fs.readFileSync('public/styles/mobile-boot-polish.css', 'utf8');

test('intro media is assigned only for the first install while every cold start keeps a branded intro', () => {
  const videoTag = html.match(/<video\s+id="introVid"[^>]*>/)?.[0] || '';
  assert.doesNotMatch(videoTag, /\ssrc=/);
  assert.match(videoTag, /data-src="\.\/assets\/intro\.mp4"/);
  assert.match(videoTag, /preload="none"/);
  const seenCheck = html.indexOf("localStorage.getItem(INTRO_INSTALL_KEY)");
  assert.ok(seenCheck >= 0);
  assert.match(html, /beginIntroFlow\(\);\s*if \(isLocalPreview\)/);
  assert.match(html, /firstInstall \? 2\.4 : 1\.8/);
  assert.match(html, /INTRO_SKIP_KEY = 'marino_intro_skip_v1'/);
});

test('intro flow uses explicit booting introPlaying ready phases and waits for boot completion', () => {
  assert.match(html, /BOOTING: 'booting', INTRO: 'introPlaying', READY: 'ready'/);
  assert.match(html, /let introFinished = false;/);
  assert.match(html, /function finishIntro\(skipped = false\)/);
  assert.match(html, /if \(introFinished \|\| !introWindowElapsed \|\| !appBootComplete\) return;/);
  assert.match(html, /clearTimeout\(introFinishTimer\)/);
  assert.match(html, /introFinishTimer = setTimeout\(\(\) => finishIntro\(false\), duration \* 1000\)/);
  assert.match(html, /markBootComplete\(\);/);
  assert.match(polishCss, /--intro-duration:\s*1\.8s/);
});

test('bottom navigation is hidden and gameplay is inert until the app is ready', () => {
  assert.match(html, /<html lang="tr" data-app-state="booting">/);
  assert.match(html, /<div id="app" inert>/);
  assert.match(html, /toggleAttribute\('inert', phase !== APP_PHASE\.READY\)/);
  assert.match(polishCss, /html:not\(\[data-app-state="ready"\]\) #app[\s\S]*pointer-events:\s*none/);
  assert.match(polishCss, /html:not\(\[data-app-state="ready"\]\) \.nav-bar[\s\S]*visibility:\s*hidden/);
  assert.match(polishCss, /body:has\(\.sheet-overlay\.show\) \.nav-bar/);
  assert.match(polishCss, /--layer-intro:\s*300000/);
  assert.match(polishCss, /--layer-critical:\s*400000/);
});

test('character remains bottom anchored and visible across the mobile viewport matrix', () => {
  assert.match(polishCss, /overflow:\s*visible !important/);
  assert.match(polishCss, /--character-size:\s*clamp\(/);
  assert.match(polishCss, /aspect-ratio:\s*1/);
  assert.match(polishCss, /transform-origin:\s*bottom center/);
  assert.match(polishCss, /object-position:\s*center bottom/);
  for (const viewport of ['320x568', '360x640', '390x844', '412x915', '480x960']) {
    assert.match(polishCss, new RegExp(`Regression matrix:[^\\n]*${viewport}`));
  }
});

test('reduced motion receives a short static intro fallback', () => {
  assert.match(html, /reducedMotion \? 1\.5/);
  assert.match(html, /intro\.classList\.toggle\('is-reduced', reducedMotion\)/);
  assert.match(polishCss, /\.intro-overlay\.is-reduced \.intro-hero \{ display: none; \}/);
  assert.match(polishCss, /@media \(prefers-reduced-motion: reduce\)/);
});

test('Empire Hub uses the shared bottom-sheet system', () => {
  assert.doesNotMatch(html, /<details[^>]*id="empireHub"/);
  assert.match(html, /id="btnEmpireHub"/);
  assert.match(html, /id="sheetEmpireHub" class="sheet-overlay"/);
  assert.match(html, /class="sheet empire-hub-sheet"/);
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
