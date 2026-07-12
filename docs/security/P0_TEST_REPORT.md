# P0 test report

Date: 2026-07-12

## Scope and constraints

Tests are local and static. No live Supabase request, database command, migration,
Edge Function deployment or GitHub Pages deployment was performed.

## Automated/local checks

Results recorded before commit:

- PASS — inline application JavaScript parsed with Node.js `vm.Script`.
- PASS — SQL structural scan found fixed `search_path` declarations, client-role
  revokes, gateway grants and RLS activation.
- PASS — all 27 RPC actions referenced by the frontend are represented in the
  authenticated gateway allowlist.
- PASS — Pages artifact contains no `admin.html`, static admin token, password
  input or removed authorization marker.
- PASS — executable frontend contains no `initDataUnsafe` reference.
- PASS — economic localStorage keys, `_offline` success branches and client award
  helpers are absent.
- PASS — `git diff --check` reported no whitespace errors (Git emitted only the
  expected Windows line-ending warning).
- NOT RUN — Edge Function Deno type-check; Deno is not installed in the local
  environment. This is a mandatory staging check before deployment.

## Not executable locally

- PostgreSQL compilation of legacy wrapper calls, because production legacy
  function definitions are not present in this repository
- Telegram HMAC integration against a real bot token
- Supabase Auth session lifetime/refresh behavior
- RLS and role authorization matrix against production data
- End-to-end Telegram Mini App execution

These must be completed on an isolated staging Supabase project using the runbook
before any production application.
