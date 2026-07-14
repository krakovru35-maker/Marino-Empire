import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const fail = (message) => { throw new Error(message); };
const assert = (condition, message) => { if (!condition) fail(message); };

const publicDir = path.join(root, 'public');
function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  });
}
const publicFiles = walk(publicDir);
const publicText = publicFiles
  .filter((file) => /\.(?:html|js)$/i.test(file))
  .map((file) => fs.readFileSync(file, 'utf8'))
  .join('\n');

assert(!fs.existsSync(path.join(publicDir, 'admin.html')), 'public/admin.html must not exist');
assert(!/(admin_token|marino_authorized|type=.password)/i.test(publicText), 'public admin credential pattern found');

const frontend = read('public/index.html');
const inlineScripts = [...frontend.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1]).filter((source) => source.trim());
new vm.Script(inlineScripts.at(-1), { filename: 'public/index.html' });

assert(!/const\s+SUPABASE_(?:URL|KEY)\s*=/.test(frontend), 'hard-coded Supabase config found');
assert(frontend.includes('__MARINO_RUNTIME_CONFIG_SCRIPT__'), 'runtime config build token missing');
assert(/window\.MARINO_CONFIG/.test(frontend) && /runtimeConfigResult/.test(frontend), 'verified runtime config bootstrap missing');
assert(!frontend.includes('initDataUnsafe'), 'frontend must not use initDataUnsafe');
assert(!/(_offline|awardCoin|awardChips|awardEnergy|m_clientBonus|m_combo_today|m_cipher_today|m_boosts_|m_perm_boost|m_airdrop)/.test(frontend), 'economic offline/localStorage path found');
assert(/persistSession:\s*false/.test(frontend), 'Supabase sessions must not persist');
assert(/autoRefreshToken:\s*true/.test(frontend), 'Supabase token refresh must be enabled');
assert(/onAuthStateChange/.test(frontend) && /TOKEN_REFRESHED/.test(frontend) && /SIGNED_OUT/.test(frontend), 'auth state listener coverage missing');
assert(/refreshSession\(\)/.test(frontend) && /lockEconomicRpc/.test(frontend), 'refresh failure economic lock missing');
assert(!/hkRpc\(['"]marino_connect_wallet/.test(frontend), 'frontend calls wallet gateway');

const gateway = read('supabase/migrations/202607120003_p0_secure_rpc.sql');
const privileges = read('supabase/migrations/202607120002_p0_function_privileges.sql');
const legacyBaseline = read('supabase/migrations/202607110001_legacy_gameplay_baseline.sql');
assert(!/when\s+'marino_connect_wallet'/i.test(gateway), 'wallet action remains in secure gateway allowlist');
assert(/revoke all on function public\.marino_connect_wallet\(text, text\) from public, anon, authenticated;/i.test(legacyBaseline), 'creation-time wallet RPC revoke missing');
assert(/from pg_proc p[\s\S]*p\.proname like 'marino\\_%'/i.test(privileges), 'legacy wallet hardening sweep missing');

const migrationDir = path.join(root, 'supabase', 'migrations');
const migrations = fs.readdirSync(migrationDir).filter((name) => name.endsWith('.sql'))
  .map((name) => fs.readFileSync(path.join(migrationDir, name), 'utf8')).join('\n');
assert(/enable row level security/i.test(migrations), 'RLS activation missing');
assert(/revoke execute[\s\S]*public, anon, authenticated/i.test(migrations), 'client role revoke missing');
assert(/grant execute[\s\S]*to authenticated/i.test(migrations), 'authenticated gateway grant missing');

for (const match of migrations.matchAll(/create or replace function[\s\S]*?\$\$;/gi)) {
  if (/security definer/i.test(match[0])) {
    assert(/set search_path = pg_catalog, public/i.test(match[0]), 'SECURITY DEFINER without fixed search_path');
  }
}

const edge = read('supabase/functions/telegram-auth/index.ts');
assert(/TELEGRAM_INIT_DATA_MAX_AGE_SECONDS/.test(edge), 'short initData lifetime control missing');
assert(/marino_check_bootstrap_rate_limit/.test(edge), 'bootstrap rate limit call missing');
assert(/withBootstrapLease/.test(edge) && /createMagicLinkSession/.test(edge), 'bootstrap lease or magic-link session missing');

const leaseMigration = read('supabase/migrations/202607120006_p0_auth_bootstrap_lease.sql');
assert(/security definer/gi.test(leaseMigration) && /set search_path = pg_catalog, public/gi.test(leaseMigration), 'lease functions are not hardened');
assert(/from public, anon, authenticated/gi.test(leaseMigration) && /to service_role/gi.test(leaseMigration), 'lease RPC privileges are not service-role-only');

const contentSchema = read('supabase/migrations/202607140001_content_operations_schema.sql');
const contentRpc = read('supabase/migrations/202607140002_content_operations_rpc.sql');
const contentEdge = read('supabase/functions/content-ops/index.ts');
const contentAdmin = read('public/js/admin/content-admin.js');
assert(/daily_content_player_active_read[\s\S]*status = 'published'[\s\S]*starts_at <= now\(\)[\s\S]*ends_at > now\(\)/.test(contentSchema), 'active content RLS policy missing');
assert(/pg_advisory_xact_lock/.test(contentRpc) && /unique \(user_id, content_id\)/.test(contentSchema), 'claim concurrency barriers missing');
assert(!/(SUPABASE_SERVICE_ROLE_KEY|sb_secret_|service.role)/i.test(contentEdge), 'privileged key reference in content Edge Function');
assert(/Authorization: authorization/.test(contentEdge), 'content Edge Function does not forward caller authorization');
assert(!/\.from\s*\(/.test(contentAdmin) && /\.rpc\s*\(/.test(contentAdmin), 'admin panel bypasses RPC gateway');
assert(!/(localStorage|admin_token|marino_authorized)/i.test(contentAdmin), 'client-derived admin authorization found');

if (fs.existsSync(path.join(root, 'dist'))) {
  const manifest = JSON.parse(read('dist/build-manifest.json'));
  const distHtml = read('dist/index.html');
  const distConfig = read(`dist/${manifest.configFile}`);
  assert(!distHtml.includes('__MARINO_RUNTIME_CONFIG_SCRIPT__'), 'built HTML still contains runtime config token');
  assert(distHtml.includes(manifest.configFile), 'built HTML does not load manifest config file');
  assert(distConfig.includes(manifest.projectRef), 'runtime config and manifest project refs differ');
  assert(!/(SUPABASE_SERVICE_ROLE_KEY|TELEGRAM_BOT_TOKEN|service_role\s*[:=])/i.test(distConfig), 'forbidden secret marker in runtime config');
}

console.log('security validation: ok');
