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
- PASS — sessions remain non-persistent, automatic refresh is enabled, and
  `TOKEN_REFRESHED`, `SIGNED_OUT`, proactive refresh failure and economic lock
  paths are present.
- PASS — frontend and secure gateway contain no wallet-connect action; the legacy
  wallet function has an explicit three-role revoke.
- PASS — short initData validity and reload-tolerant bootstrap rate-limit wiring
  are present. This is not recorded as full replay prevention.
- PASS — `git diff --check` reported no whitespace errors (Git emitted only the
  expected Windows line-ending warning).
- CI REQUIRED — the PR validation job installs Deno and type-checks the Edge
  Function. Its result is reported after the second commit is pushed.

## Not executable locally

- PostgreSQL compilation of legacy wrapper calls, because production legacy
  function definitions are not present in this repository
- Telegram HMAC integration against a real bot token
- Supabase Auth session lifetime/refresh behavior
- RLS and role authorization matrix against production data
- End-to-end Telegram Mini App execution

These must be completed on an isolated staging Supabase project using the runbook
before any production application.

## Fifteen-minute session scenario

1. Configure staging access-token expiry to 900 seconds and refresh rotation on.
2. Open the game through Telegram and keep it active for at least 17 minutes.
3. Observe `TOKEN_REFRESHED`; verify no Supabase token appears in localStorage or
   sessionStorage, then perform a low-value authenticated RPC.
4. Revoke the refresh token/session, advance to the next refresh point, and verify
   the listener locks economic RPCs and displays the Telegram reopen instruction.

This scenario is specified but cannot be truthfully marked passed until the Edge
Function and migrations exist in isolated staging.
