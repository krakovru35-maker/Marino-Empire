import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';
import { buildArtifact, validateBuildInput } from '../scripts/runtime-config-lib.mjs';

const stagingRef = 'stagingref0000000001';
const productionRef = 'productionref0000000';
const publishableKey = 'sb_publishable_ci_placeholder_not_secret';
const commitSha = '0123456789abcdef0123456789abcdef01234567';

function input(overrides = {}) {
  return {
    targetEnvironment: 'staging',
    supabaseUrl: `https://${stagingRef}.supabase.co`,
    supabasePublishableKey: publishableKey,
    expectedProjectRef: stagingRef,
    productionProjectRef: productionRef,
    stagingProjectRef: stagingRef,
    commitSha,
    buildTime: '2026-07-13T00:00:00.000Z',
    ...overrides,
  };
}

test('build creates matching HTML, config and manifest with cache-busted filename', () => {
  const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), 'marino-runtime-'));
  const publicDir = path.join(rootDir, 'public');
  const distDir = path.join(rootDir, 'dist');
  fs.cpSync(path.resolve('public'), publicDir, { recursive: true });
  const manifest = buildArtifact({ rootDir, publicDir, distDir, input: input() });
  assert.equal(manifest.configFile, `runtime-config.${commitSha.slice(0, 12)}.js`);
  assert.match(fs.readFileSync(path.join(distDir, 'index.html'), 'utf8'), new RegExp(manifest.configFile.replaceAll('.', '\\.')));
  assert.match(fs.readFileSync(path.join(distDir, 'admin-content.html'), 'utf8'), new RegExp(manifest.configFile.replaceAll('.', '\\.')));
  assert.doesNotMatch(fs.readFileSync(path.join(distDir, 'admin-content.html'), 'utf8'), /__MARINO_RUNTIME_CONFIG_SCRIPT__/);
  assert.match(fs.readFileSync(path.join(distDir, manifest.configFile), 'utf8'), new RegExp(stagingRef));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(distDir, 'build-manifest.json'), 'utf8')), manifest);
  assert.equal(fs.existsSync(path.join(publicDir, manifest.configFile)), false);
});

test('cross-environment refs and secret key shapes fail closed', () => {
  assert.throws(() => validateBuildInput(input({ supabaseUrl: `https://${productionRef}.supabase.co` })));
  assert.throws(() => validateBuildInput(input({ targetEnvironment: 'production', expectedProjectRef: stagingRef })));
  assert.throws(() => validateBuildInput(input({ supabasePublishableKey: 'service_role_forbidden' })));
});

test('artifact scan rejects cross-environment refs in both directions', () => {
  for (const scenario of [
    { targetEnvironment: 'staging', actual: stagingRef, expected: stagingRef, leak: productionRef },
    { targetEnvironment: 'production', actual: productionRef, expected: productionRef, leak: stagingRef },
  ]) {
    const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), 'marino-cross-ref-'));
    const publicDir = path.join(rootDir, 'public');
    fs.cpSync(path.resolve('public'), publicDir, { recursive: true });
    fs.writeFileSync(path.join(publicDir, 'cross-ref-leak.js'), `window.leak = '${scenario.leak}';\n`);
    assert.throws(() => buildArtifact({
      rootDir, publicDir, distDir: path.join(rootDir, 'dist'),
      input: input({
        targetEnvironment: scenario.targetEnvironment,
        supabaseUrl: `https://${scenario.actual}.supabase.co`,
        expectedProjectRef: scenario.expected,
      }),
    }), /cross-environment project ref/);
  }
});

test('runtime loader validates config and masks staging diagnostics', () => {
  const context = { window: {}, URL, document: { createElement: () => ({ style: {} }), body: { appendChild() {} } } };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync('public/runtime-config-loader.js', 'utf8'), context);
  const result = context.window.MarinoRuntimeConfig.read({
    targetEnvironment: 'staging', supabaseUrl: `https://${stagingRef}.supabase.co`,
    supabasePublishableKey: publishableKey, projectRef: stagingRef,
    commitSha, buildTime: '2026-07-13T00:00:00.000Z'
  });
  assert.equal(result.ok, true);
  assert.equal(context.window.MarinoRuntimeConfig.maskProjectRef(stagingRef), 'stag…0001');
  assert.equal(context.window.MarinoRuntimeConfig.read(null).ok, false);
});
