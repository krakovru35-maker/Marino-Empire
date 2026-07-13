# Staging baseline dependency report

Date: 2026-07-14

Branch: `feature/supabase-content-ops`
Decision: **B — canonical legacy definitions are incomplete in this repository.**

This is a source-only audit. No staging or production database operation is part
of this report. The known staging state is intentionally left unchanged:
`202607120001_p0_identity_roles_rls.sql` is applied and
`202607120002_p0_function_privileges.sql` and all later migrations are not.

## Executive finding

The repository cannot build the application database from an empty Supabase
project. `supabase_migration.sql` is an add-on for Daily Combo/Cipher, boosts and
wallet/airdrop. It is not a gameplay baseline. It requires `marino_players`, and
the secure gameplay and admin gateways require many legacy functions whose
definitions and transitive table dependencies are absent.

Copying `supabase_migration.sql` into the migration chain would also restore
unsafe behavior: its `SECURITY DEFINER` functions do not set a trusted
`search_path`, accept caller-supplied Telegram identities, grant direct execution
to `anon` and `authenticated`, contain economy constants, and synthesize a wallet
address without ownership proof. It therefore cannot be treated as canonical or
applied unchanged.

## Repository SQL inventory

The repository contains only:

- `supabase_migration.sql`: four add-on tables and thirteen Daily/Boost/Wallet
  functions. It depends on a missing `marino_players` table.
- `supabase/migrations/202607120001` through `202607120006`: P0 identity,
  privilege, authenticated gateway, admin gateway and auth bootstrap controls.
- `supabase/migrations/202607140001` through `202607140003`: Content Operations
  schema, RPCs and reporting.
- Two pgTAP files covering Content Operations authorization and claim structure.

There are no SQL files under `backend/`; that directory contains only Python
application/asset files. README material explicitly says the live legacy
function definitions are not stored in this repository.

## Migration dependency matrix

### `202607120001_p0_identity_roles_rls.sql`

Pre-existing requirements:

- Supabase-managed `auth.users` and `auth.uid()`.
- Supabase roles `anon` and `authenticated`.
- Built-in types `uuid`, `text`, `jsonb`, `timestamptz`, and identity sequences.

Creates:

- Tables: `marino_identity_links`, `marino_admin_roles`,
  `marino_admin_audit_log`, `marino_idempotency_keys`.
- Functions: `marino_current_telegram_id()`, `marino_is_admin(text[])`.
- One automatically owned identity sequence for the audit-log ID.

Missing repository dependency: none. This migration is independently complete
for a normal Supabase project and is already applied to staging. It must not be
edited retroactively.

### `202607120002_p0_function_privileges.sql`

Intended pre-existing requirements:

- The complete legacy gameplay baseline.
- Functions selected dynamically by the `pg_proc` loop: every public
  `marino_*` function plus `start_game`, `tap_coin`, `collect_income`,
  `upgrade_building`, and `request_reward`.
- Explicit functions: `marino_get_today_combo()`,
  `marino_get_today_cipher()`, `marino_connect_wallet(text,text)`.
- Explicit tables: `marino_daily_combo`, `marino_daily_cipher`,
  `marino_player_boosts`, `marino_wallets`.
- Roles `anon` and `authenticated`; built-in `regprocedure` support.

Repository status:

- The four tables and three explicit functions appear only in
  `supabase_migration.sql`, which is not a complete or safe baseline.
- The generic `pg_proc` loop already covers those three functions whenever they
  exist; the direct function `REVOKE` statements are redundant and fail when the
  objects are absent.
- `ALTER TABLE IF EXISTS` is conditional, but the following direct table
  `REVOKE` statements are not and also fail when a table is absent.

Safe eventual boundary:

- Every canonical `SECURITY DEFINER` function must be created with a fixed
  `search_path` and revoked from `PUBLIC`, `anon`, and `authenticated` in the
  same migration that creates it, unless it is an explicitly authenticated
  gateway.
- A hardening sweep may remain after the baseline. Optional-object operations
  should resolve the exact object with `to_regprocedure(...)` or
  `to_regclass(...)` inside a guarded block. This is defense in depth, not a
  replacement for the missing baseline or correct creation order.

### `202607120003_p0_secure_rpc.sql`

Pre-existing requirements from `202607120001`:

- `marino_current_telegram_id()` and `marino_idempotency_keys`.

Pre-existing legacy functions called by the gateway:

- Present only in the non-canonical add-on SQL:
  - `marino_get_today_cipher()`
  - `marino_hk_state(text)`
  - `marino_claim_combo(text,text[])`
  - `marino_claim_cipher(text,text)`
  - `marino_use_full_energy(text)`
  - `marino_use_tap_boost(text)`
  - `marino_upgrade_multitap(text)`
  - `marino_upgrade_energy_limit(text)`
  - `marino_activate_auto_tap(text)`
- Missing entirely from repository SQL:
  - `start_game(text,text,text,text,text,text)`
  - `tap_coin(text,integer)`
  - `collect_income(text,text)`
  - `marino_play_slot(text,bigint,text)`
  - `marino_play_mini_game(text,text,text)`
  - `marino_buy_chips(text,bigint)`
  - `marino_get_referrals(text)`
  - `marino_check_coupons(text)`
  - `marino_get_my_notifications(text)`
  - `marino_claim_daily_login(text,text)`
  - `marino_upgrade_tap(text,text)`
  - `marino_upgrade_capacity(text,text)`
  - `upgrade_building(text,text,text)`
  - `marino_claim_task(text,text,integer,text)`
  - `request_reward(text,text,text)`
  - `marino_claim_referral(text,text,text)`
  - `marino_prestige(text,text)`
  - `marino_get_leaderboard(integer,integer,integer)`
  - `marino_play_roulette_v2(text,jsonb,text)`
  - `marino_bj_deal(text,bigint)`
  - `marino_bj_hit(text)`
  - `marino_bj_stand(text)`
  - `marino_play_horse_racing(text,bigint,integer)`
  - `marino_play_poker(text,bigint)`
  - `marino_get_live_matches()`
  - `marino_place_sports_bet(text,bigint,text,bigint)`

The signatures above are the compatibility signatures implied by the gateway
calls, not proof of the live canonical signatures. They must be compared with a
schema-only source before the gateway is considered compatible.

Creates:

- `_marino_cipher_hint()` and `marino_secure_rpc(text,jsonb,uuid)`.

The SQL helper `_marino_cipher_hint()` directly resolves
`marino_get_today_cipher()` at creation. The PL/pgSQL gateway also cannot be
accepted without all legacy signatures and dependencies being verified.

### `202607120004_p0_admin_gateway.sql`

Pre-existing requirements from `202607120001`:

- `marino_admin_roles` and `marino_admin_audit_log`.

Missing legacy admin functions:

- `marino_admin_get_users(text)`
- `marino_admin_get_requests(text)`
- `marino_admin_update_user(text,text,bigint,bigint,integer)`
- `marino_admin_toggle_ban(text,text)`
- `marino_admin_resolve_request(text,bigint,text,text)`

Creates `marino_admin_rpc(text,jsonb,uuid)`. Its legacy dependencies and their
transitive tables are absent, so the gateway is not buildable from this repo.

### `202607120005_p0_auth_bootstrap_rate_limit.sql`

Requires only standard Supabase roles and built-in PostgreSQL types/functions.
Creates `marino_auth_bootstrap_limits` and
`marino_check_bootstrap_rate_limit(text,text,integer,integer)`. It is otherwise
independent and grants only `service_role` execution.

### `202607120006_p0_auth_bootstrap_lease.sql`

Requires only standard Supabase roles and built-in PostgreSQL types/functions.
Creates `marino_auth_bootstrap_leases`,
`marino_acquire_auth_bootstrap_lease(text,uuid,integer)`, and
`marino_release_auth_bootstrap_lease(text,uuid)`. It is otherwise independent and
grants only `service_role` execution.

### `202607140001_content_operations_schema.sql`

Pre-existing requirements:

- Supabase-managed `auth.users`, `auth.uid()`, roles, and the `extensions`
  schema.
- `pgcrypto`, created by this migration in `extensions`.

Creates Content Operations tables, indexes, an update trigger and
`content_set_updated_at()`. It has no dependency on legacy gameplay tables. It
uses only built-in types; UUID defaults come from `pgcrypto`. Identity/UUID
sequences are automatically owned and no custom type or standalone sequence is
expected.

### `202607140002_content_operations_rpc.sql`

Requires every table and `pgcrypto` function created by `202607140001`, plus
Supabase `auth.uid()`. Creates the player and admin Content Operations RPCs. All
`SECURITY DEFINER` functions have a fixed `search_path`; internal helpers are
revoked and externally callable functions are limited to `authenticated` with
authorization enforced inside the function.

### `202607140003_content_admin_reporting.sql`

Requires `content_admin_role()`, `daily_content`,
`player_content_attempts`, and `player_content_claims` from the two preceding
Content Operations migrations. It replaces `admin_get_daily_content()` and
retains a fixed `search_path` and authenticated-only execution.

## Missing tables and schema details

Directly proven missing canonical table:

- `public.marino_players`.

The add-on SQL proves at least these expected columns:

- `telegram_id`, `marino_coin`, `updated_at`, `energy`, `max_energy`,
  `last_energy_update`, `tap_power`, `casino_level`, `casino_chips`,
  `reputation`, `referred_by`, and `completed_tasks`.

Their exact types, defaults, constraints, indexes, RLS policies, triggers and
relationships are not present and must not be inferred. The missing gameplay
and admin functions almost certainly require additional tables, types,
sequences and extensions, but their names cannot be established from this
repository without inventing schema. A schema-only baseline is required to list
those transitive objects accurately.

The following add-on tables have definitions in `supabase_migration.sql` but are
not canonical baseline definitions: `marino_daily_combo`,
`marino_daily_cipher`, `marino_player_boosts`, and `marino_wallets`.

## Security assessment of `supabase_migration.sql`

- All twelve `SECURITY DEFINER` functions omit a fixed `search_path`.
- Player identity is accepted through `p_telegram_id` instead of being derived
  from `auth.uid()` and a verified identity link.
- Sensitive/economic functions are granted directly to both `anon` and
  `authenticated`.
- Reward, boost cost, multiplier and duration formulas are embedded in this
  historical file; importing it could change or resurrect old economy behavior.
- `marino_connect_wallet` can generate a placeholder address and does not prove
  wallet ownership.
- Objects are not consistently schema-qualified.
- Direct player-state updates depend on the missing `marino_players` contract.

The file is useful evidence of historical signatures only. It must not be copied
or executed as a migration.

## Required canonical schema-only acquisition

Because the repository is incomplete, an authorized database operator must
capture a schema-only baseline. Codex must not connect to production or receive
database credentials.

1. In an approved read-only operator environment, verify the intended source
   project independently. Use a temporary least-privilege read-only database
   role and keep its connection details outside Git, logs and this task.
2. Run `pg_dump` in schema-only mode for `public`, with owner and privilege
   emission disabled. Do not request or export table data, `auth.users` rows,
   storage objects or secrets. Example shape (operator substitutes the connection
   securely):

   ```powershell
   pg_dump --schema-only --no-owner --no-privileges --schema=public --file=marino-public-schema.sql "<operator-managed-read-only-connection>"
   ```

3. Separately export read-only metadata for exact function identity arguments,
   return types, `SECURITY DEFINER`, `proconfig`, ACLs, table columns,
   constraints, indexes, triggers, RLS flags/policies, owned sequences,
   extensions and function dependencies. The P0 runbook queries are the minimum,
   not the full audit.
4. Remove environment-specific ownership/comments, inspect every function body,
   and compare its hash/signature with the application contract. Never commit
   credentials, data rows or unreviewed dump output.
5. Convert the reviewed objects into a deterministic baseline migration. Do not
   blindly rename the raw dump or `supabase_migration.sql` into a migration.
6. In the same creation migration, fix each definer `search_path` and close
   direct execution; expose only reviewed gateways. Any behavior-changing fix
   requires separate economy/security approval.

## Proposed migration order after canonical recovery

No file is renamed by this audit. The target clean-project order is:

1. `202607110001_legacy_gameplay_baseline.sql` — new, reviewed canonical schema
   and exact legacy functions, with safe ownership/search paths/ACL boundaries.
2. `202607120001_p0_identity_roles_rls.sql` — unchanged.
3. A reviewed successor to `202607120002_p0_function_privileges.sql` — only
   after the baseline exists; remove redundant direct revokes or guard exact
   optional objects with `to_regprocedure`/`to_regclass`.
4. `202607120003_p0_secure_rpc.sql` after all exact compatibility signatures
   pass.
5. `202607120004_p0_admin_gateway.sql` after all legacy admin signatures pass.
6. `202607120005_p0_auth_bootstrap_rate_limit.sql`.
7. `202607120006_p0_auth_bootstrap_lease.sql`.
8. `202607140001_content_operations_schema.sql`.
9. `202607140002_content_operations_rpc.sql`.
10. `202607140003_content_admin_reporting.sql`.

Because `202607120001` is already recorded in the current staging project, this
order must be validated on a freshly recreated staging project. Do not fake or
repair migration history to make the partial project appear clean.

## Clean staging reset/recreate procedure (not executed)

The staging project is new and has no user data. After the canonical baseline is
reviewed and a new explicit staging-write approval is granted:

1. Preserve this report and the failed migration evidence; do not run migration
   repair against the partial project.
2. Prefer creating a fresh empty staging project rather than mutating migration
   history. Verify its project name/ref and confirm it is the only linked project.
3. Configure only required staging Auth settings and secrets through the approved
   operator path; never copy production secrets or user data.
4. Run `migration list --linked`, then `db push --linked --dry-run`; require the
   exact clean order above and an empty remote history.
5. Apply once to the fresh staging project. Never rerun migration files manually.
6. Run object-existence, function-signature, RLS, ACL, gateway, Telegram-auth,
   Content Operations authorization and real two-session claim-concurrency tests.
7. Only after acceptance, retire the partial staging project through a separately
   approved destructive operation.

An in-place database reset is a secondary option only with explicit destructive
approval and a verified no-data condition. It must not be combined with migration
repair.

## Empty-database test strategy

On an isolated local Supabase instance or newly approved empty staging project:

1. Apply the complete migration chain once from an empty history.
2. Assert every required table, function, exact signature, extension, index,
   trigger and RLS policy exists.
3. Assert no migration is manually executed a second time; a second migration
   status check must show no pending files.
4. Assert `PUBLIC`, `anon`, and `authenticated` lack execution on every sensitive
   legacy function, including answer, wallet and economy RPCs.
5. Assert `marino_secure_rpc` and `marino_admin_rpc` compile and route only to the
   reviewed exact signatures.
6. Exercise Telegram bootstrap rate-limit/lease functions only as
   `service_role` and verify client roles cannot execute them.
7. Run existing Content Operations pgTAP authorization tests and a true
   two-session claim race.
8. Verify failure paths do not create player rewards, entitlements, economy
   changes or audit gaps.

Local execution is currently blocked: the Docker engine is unavailable, so a
local Supabase database cannot start. Existing pgTAP files also cover only
Content Operations, not the missing legacy baseline. No staging retry was made.

## Blockers before another staging write approval

- Obtain and security-review the canonical schema-only legacy baseline.
- Resolve exact signatures and transitive dependencies for all missing gameplay
  and admin functions.
- Establish the exact `marino_players` definition and every additional legacy
  table/type/sequence/extension.
- Convert the baseline without importing unsafe grants, caller-trusted identity,
  wallet placeholders or unreviewed economy behavior.
- Review the successor privilege migration and creation-time ACL boundaries.
- Add empty-database legacy object/ACL/gateway tests and run them with a working
  local Supabase/Docker environment.
- Recreate staging cleanly; do not continue the current partial migration history.
