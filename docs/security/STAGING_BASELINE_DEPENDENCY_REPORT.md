# Staging baseline dependency report

Date: 2026-07-14

Branch: `feature/supabase-content-ops`
Decision: **Canonical legacy definitions recovered from a reviewed production
schema-only export; clean staging execution remains untested.**

This is a source-only audit. No staging or production database operation is part
of this report. The known staging state is intentionally left unchanged:
`202607120001_p0_identity_roles_rls.sql` is applied and
`202607120002_p0_function_privileges.sql` and all later migrations are not.

## Executive finding

The previous audit correctly found that the repository could not build the
application database from an empty Supabase project. A later read-only,
schema-only production export supplied the missing canonical definitions. The
reviewed result is now captured in
`202607110001_legacy_gameplay_baseline.sql`: 24 tables, 17 owned sequences, 50
constraints (including 12 foreign keys), 10 indexes and 74 installable function
overloads. Five stale production functions with four absent table dependencies
are inventoried but deliberately excluded.

Copying `supabase_migration.sql` into the migration chain would also restore
unsafe behavior: its `SECURITY DEFINER` functions do not set a trusted
`search_path`, accept caller-supplied Telegram identities, grant direct execution
to `anon` and `authenticated`, contain economy constants, and synthesize a wallet
address without ownership proof. It therefore cannot be treated as canonical or
applied unchanged.

## Repository SQL inventory

The repository now contains:

- `supabase_migration.sql`: four add-on tables and thirteen Daily/Boost/Wallet
  functions. It remains historical evidence only and is not the baseline.
- `supabase/migrations/202607110001_legacy_gameplay_baseline.sql`: reviewed
  canonical legacy DDL without production rows, owners, secrets or managed
  `auth`/`storage` schema definitions.
- `supabase/migrations/202607120001` through `202607120006`: P0 identity,
  privilege, authenticated gateway, admin gateway and auth bootstrap controls.
- `supabase/migrations/202607140001` through `202607140003`: Content Operations
  schema, RPCs and reporting.
- Two pgTAP files covering Content Operations authorization and claim structure,
  plus a static canonical-baseline security/dependency test.

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

Canonical legacy functions called by the gateway are now defined in
`202607110001`. The recovered exact signatures showed four gateway mismatches:

- Existing Daily/Boost/HK functions:
  - `marino_get_today_cipher()`
  - `marino_hk_state(text)`
  - `marino_claim_combo(text,text[])`
  - `marino_claim_cipher(text,text)`
  - `marino_use_full_energy(text)`
  - `marino_use_tap_boost(text)`
  - `marino_upgrade_multitap(text)`
  - `marino_upgrade_energy_limit(text)`
  - `marino_activate_auto_tap(text)`
- Recovered core/casino/social functions:
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
  - `marino_get_leaderboard(text,text,integer,integer)`
  - `marino_play_roulette_v2(text,jsonb,text)`
  - `marino_bj_deal(text,bigint)`
  - `marino_bj_hit(text)`
  - `marino_bj_stand(text)`
  - `marino_play_horse_racing(text,integer,integer)`
  - `marino_play_poker(text,integer)`
  - `marino_get_live_matches()`
  - `marino_place_sports_bet(text,uuid,text,bigint)`

The gateway now passes scope/country/level arguments to the canonical leaderboard
signature, validates and casts sports match IDs as UUID, safely narrows bounded
horse/poker bets to integer, and uses the canonical integer admin request ID.

Creates:

- `_marino_cipher_hint()` and `marino_secure_rpc(text,jsonb,uuid)`.

The SQL helper `_marino_cipher_hint()` and every PL/pgSQL gateway dependency now
resolve statically to a canonical baseline function.

### `202607120004_p0_admin_gateway.sql`

Pre-existing requirements from `202607120001`:

- `marino_admin_roles` and `marino_admin_audit_log`.

Recovered legacy admin functions:

- `marino_admin_get_users(text)`
- `marino_admin_get_requests(text)`
- `marino_admin_update_user(text,text,bigint,bigint,integer)`
- `marino_admin_toggle_ban(text,text)`
- `marino_admin_resolve_request(text,integer,text,text)`

Creates `marino_admin_rpc(text,jsonb,uuid)`. All five legacy admin dependencies
and their transitive reward-request table now exist in the baseline.

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

## Recovered tables and schema details

The canonical `public.marino_players` definition and all transitive legacy tables
were recovered. The baseline contains 24 tables, including:

- `public.marino_players`
- building, task, season, achievement and daily-login state
- Combo/Cipher, boosts, wallet and processed-request state
- reward/store/sink state
- sports matches, teams, players and coupons

The canonical player table includes the previously expected columns:

- `telegram_id`, `marino_coin`, `updated_at`, `energy`, `max_energy`,
  `last_energy_update`, `tap_power`, `casino_level`, `casino_chips`,
  `reputation`, `referred_by`, and `completed_tasks`.

Exact types, defaults, constraints, indexes and relationships are now carried by
the baseline. The production export contained no custom public types, views,
materialized views or triggers.

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

## Completed canonical schema-only acquisition

An authorized operator supplied a repository-external public schema-only dump.
It was read locally without database credentials and passed these gates:

1. No top-level `COPY` or `INSERT`, `auth.users` rows, e-mail/Telegram values,
   secrets, database password or connection URI was present.
2. The raw dump stayed outside the repository and is not tracked.
3. All 74 included production function bodies compare equal to the baseline after
   newline and trailing-whitespace normalization; no included economy body was rewritten.
4. Owner/schema dump scaffolding and nine permissive `USING (true)` policies were
   not imported.
5. All 64 included `SECURITY DEFINER` functions now fix `search_path` to
   `pg_catalog, public`; all baseline tables, sequences and functions are revoked
   from `PUBLIC`, `anon` and `authenticated` until P0 gateways grant entry points.

## Canonical migration order

The target clean-project order is:

1. `202607110001_legacy_gameplay_baseline.sql` — new, reviewed canonical schema
   and exact legacy functions, with safe ownership/search paths/ACL boundaries.
2. `202607120001_p0_identity_roles_rls.sql` — unchanged.
3. `202607120002_p0_function_privileges.sql` — generic `pg_proc` sweep retained;
   redundant signature-specific direct revokes removed.
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

Local execution remains blocked: the Docker engine is unavailable, so a clean
local Supabase database cannot start. Static baseline tests cover inventory,
data/secret absence, safe definer search paths, revokes, exact gateway signatures
and complete gateway dependency resolution. No staging retry was made.

## Blockers before another staging write approval

- Run the complete chain on a genuinely empty local Supabase database once
  Docker is available; static parsing cannot prove PostgreSQL execution.
- Confirm actual post-migration ACLs, RLS, exact function resolution and
  compilation with catalog queries/pgTAP.
- Exercise Telegram auth and both gateways with authenticated staging sessions.
- Run a real two-session claim concurrency test.
- Recreate staging cleanly; do not continue the current partial migration history.
