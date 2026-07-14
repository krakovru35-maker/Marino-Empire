import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const migration = await readFile(
  new URL('../supabase/migrations/202607140005_content_admin_role_fail_closed.sql', import.meta.url),
  'utf8',
);

test('missing content admin role resolves to a fail-closed sentinel', () => {
  assert.match(migration, /select\s+coalesce\s*\(\s*\(\s*select\s+role/is);
  assert.match(migration, /\),\s*''\s*\)/s);
});

test('content admin role helper remains private and hardened', () => {
  assert.match(migration, /security\s+definer/i);
  assert.match(migration, /set\s+search_path\s*=\s*pg_catalog,\s*public/i);
  assert.match(
    migration,
    /revoke\s+all\s+on\s+function\s+public\.content_admin_role\(\)\s+from\s+public,\s*anon,\s*authenticated/i,
  );
});
