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

assert(!frontend.includes('initDataUnsafe'), 'frontend must not use initDataUnsafe');
assert(!/(_offline|awardCoin|awardChips|awardEnergy|m_clientBonus|m_combo_today|m_cipher_today|m_boosts_|m_perm_boost|m_airdrop)/.test(frontend), 'economic offline/localStorage path found');
assert(/persistSession:\s*false/.test(frontend), 'Supabase sessions must not persist');
assert(/autoRefreshToken:\s*true/.test(frontend), 'Supabase token refresh must be enabled');
assert(/onAuthStateChange/.test(frontend) && /TOKEN_REFRESHED/.test(frontend) && /SIGNED_OUT/.test(frontend), 'auth state listener coverage missing');
assert(/refreshSession\(\)/.test(frontend) && /lockEconomicRpc/.test(frontend), 'refresh failure economic lock missing');
assert(!/hkRpc\(['"]marino_connect_wallet/.test(frontend), 'frontend calls wallet gateway');

const gateway = read('supabase/migrations/202607120003_p0_secure_rpc.sql');
const privileges = read('supabase/migrations/202607120002_p0_function_privileges.sql');
assert(!/when\s+'marino_connect_wallet'/i.test(gateway), 'wallet action remains in secure gateway allowlist');
assert(/revoke execute on function public\.marino_connect_wallet\(text,text\) from public, anon, authenticated;/i.test(privileges), 'legacy wallet RPC revoke missing');

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

console.log('security validation: ok');
