import fs from 'node:fs';
import path from 'node:path';

const PROJECT_REF_PATTERN = /^[a-z0-9]{20}$/;
const KEY_PATTERN = /^sb_publishable_[A-Za-z0-9_-]{8,}$/;
const HTML_TOKEN = '__MARINO_RUNTIME_CONFIG_SCRIPT__';

export function projectRefFromUrl(value) {
  const url = new URL(value);
  if (url.protocol !== 'https:') throw new Error('Supabase URL must use HTTPS');
  const match = url.hostname.match(/^([a-z0-9]{20})\.supabase\.co$/);
  if (!match) throw new Error('Supabase URL must contain a 20-character project ref');
  return match[1];
}

export function validateBuildInput(input) {
  if (!['staging', 'production'].includes(input.targetEnvironment)) throw new Error('targetEnvironment must be staging or production');
  if (!PROJECT_REF_PATTERN.test(input.expectedProjectRef || '')) throw new Error('expected project ref is invalid');
  if (!PROJECT_REF_PATTERN.test(input.productionProjectRef || '')) throw new Error('production project ref is invalid');
  if (!PROJECT_REF_PATTERN.test(input.stagingProjectRef || '')) throw new Error('staging project ref is invalid');
  if (input.productionProjectRef === input.stagingProjectRef) throw new Error('production and staging refs must differ');
  const actualRef = projectRefFromUrl(input.supabaseUrl);
  if (actualRef !== input.expectedProjectRef) throw new Error('Supabase URL project ref mismatch');
  if (input.targetEnvironment === 'staging' && actualRef === input.productionProjectRef) throw new Error('staging build contains production ref');
  if (input.targetEnvironment === 'production' && actualRef === input.stagingProjectRef) throw new Error('production build contains staging ref');
  if (!KEY_PATTERN.test(input.supabasePublishableKey || '')) throw new Error('publishable key format is invalid');
  if (!/^[0-9a-f]{7,40}$/i.test(input.commitSha || '')) throw new Error('commit SHA is invalid');
  return { ...input, actualRef, buildTime: input.buildTime || new Date().toISOString() };
}

function safeCleanDist(rootDir, distDir) {
  const resolvedRoot = path.resolve(rootDir);
  const resolvedDist = path.resolve(distDir);
  if (path.dirname(resolvedDist) !== resolvedRoot || path.basename(resolvedDist) !== 'dist') {
    throw new Error('refusing to clean an unsafe dist path');
  }
  fs.rmSync(resolvedDist, { recursive: true, force: true });
  fs.mkdirSync(resolvedDist, { recursive: true });
}

function scanArtifact(distDir, config) {
  const walk = (directory) => fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  });
  const files = walk(distDir);
  const text = files.filter((file) => /\.(?:html|js|json)$/i.test(file))
    .map((file) => fs.readFileSync(file, 'utf8')).join('\n');
  const forbiddenRef = config.targetEnvironment === 'staging' ? config.productionProjectRef : config.stagingProjectRef;
  if (text.includes(forbiddenRef)) throw new Error('artifact contains cross-environment project ref');
  if (/(SUPABASE_SERVICE_ROLE_KEY|TELEGRAM_BOT_TOKEN|service_role\s*[:=])/i.test(text)) {
    throw new Error('artifact contains a forbidden secret marker');
  }
}

export function buildArtifact({ rootDir, publicDir, distDir, input }) {
  const config = validateBuildInput(input);
  safeCleanDist(rootDir, distDir);
  fs.cpSync(publicDir, distDir, { recursive: true });

  for (const name of fs.readdirSync(distDir)) {
    if (/^runtime-config\.[0-9a-f]+\.js$/i.test(name)) fs.rmSync(path.join(distDir, name));
  }

  const configFile = `runtime-config.${config.commitSha.slice(0, 12)}.js`;
  const runtimeConfig = {
    targetEnvironment: config.targetEnvironment,
    supabaseUrl: config.supabaseUrl,
    supabasePublishableKey: config.supabasePublishableKey,
    projectRef: config.actualRef,
    commitSha: config.commitSha,
    buildTime: config.buildTime,
  };
  fs.writeFileSync(path.join(distDir, configFile), `window.MARINO_CONFIG = ${JSON.stringify(runtimeConfig)};\n`, 'utf8');

  const htmlPath = path.join(distDir, 'index.html');
  const sourceHtml = fs.readFileSync(htmlPath, 'utf8');
  if (!sourceHtml.includes(HTML_TOKEN)) throw new Error('runtime config HTML token is missing');
  fs.writeFileSync(htmlPath, sourceHtml.replace(HTML_TOKEN, configFile), 'utf8');

  const manifest = { targetEnvironment: config.targetEnvironment, projectRef: config.actualRef, commitSha: config.commitSha, buildTime: config.buildTime, configFile };
  fs.writeFileSync(path.join(distDir, 'build-manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  scanArtifact(distDir, config);
  return manifest;
}
