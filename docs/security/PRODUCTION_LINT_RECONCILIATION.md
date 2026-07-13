# Production Legacy Function Lint Reconciliation

## Scope and evidence

This review covers production project `marino-empire` and the twelve functions
reported by `supabase db lint --schema public --level error`. Evidence was
captured read-only from `pg_proc`, `pg_depend`, `pg_class`,
`information_schema.columns`, `pg_trigger`, `pg_views`, and
`pg_stat_statements`. The evidence file remains outside the repository beside
the verified production backups.

The evidence contained no embedded credential value. No trigger, view, cron,
repository caller, reviewed gateway caller, or observed statement-statistics
entry reached the stale function family described below. The only internal
callers were other members of the same superseded family.

## Canonical production relations

- `marino_players` uses `last_energy_update` and `last_income_collect`; it does
  not contain `last_energy_at` or `last_income_at`.
- `marino_store_items` uses `is_active`; it has no `category` or `active`
  column.
- `marino_player_buildings` contains only its identifier, `player_id`,
  `building_key`, and `level`.
- `marino_reward_requests` uses `reviewed_at`; it has no `updated_at` column.
- `marino_game_state`, `marino_user_buildings`, `users`, `player_state`, and
  `leaderboard` do not exist in the production public schema.
- `tmp_poker_matchups` is intentionally a transaction-local temporary table
  created inside `marino_play_poker`; no permanent relation exists or is
  required.

## Reachability and resolution

| Function | Class | Evidence and resolution |
| --- | --- | --- |
| `_marino_refresh_energy` | C | Called only by stale `_marino_state`; referenced a renamed timestamp. Signature retained fail-closed. |
| `_marino_seed_store` | C | Called only by stale `_marino_state`; referenced removed store columns. Signature retained fail-closed. |
| `_marino_state` | C | Called only by stale wrappers `get_game_state` and `marino_state`; no active client/repository/gateway usage. Signature retained fail-closed. |
| `marino_recalculate_income` | C | Called only by stale `marino_bootstrap`; both required absent relations. Signature retained fail-closed. |
| `marino_bootstrap` | C | No active caller and requires absent legacy relations. Signature retained fail-closed. |
| `sync_leaderboard` | C | No caller and requires three absent relations. Signature retained fail-closed. |
| `marino_admin_resolve_request(text,integer,text)` | B | Same admin operation family as the reviewed four-argument overload. `updated_at` is corrected to canonical `reviewed_at`; direct client execution remains revoked. |
| `_marino_seed_buildings` | C | Called only by stale `_marino_state`; expected a superseded denormalized table shape. Signature retained fail-closed. |
| `_marino_recalc_income` | C | Called only by stale `_marino_state`; expected removed denormalized income columns. Signature retained fail-closed. |
| `marino_touch_state` | C | No active caller and requires absent `marino_game_state`. Signature retained fail-closed. |
| `marino_sync_player` | C | No active caller and requires absent `marino_building_defs` plus superseded columns. Signature retained fail-closed. |
| `marino_play_poker` | A/D | Called by `marino_secure_rpc`. The temporary table exists at runtime, making the lint finding a static-analysis false positive. Static temp-table reads and seed insertion are converted to dynamic `pg_temp` statements while preserving the exact live matchup catalogue, RNG, bet deduction, payout, and response body. |

The known stale SQL functions `marino_income_per_hour`, `marino_state`, and
`marino_upgrades`, plus their obsolete wrappers `get_game_state` and
`marino_upgrades_json`, are also retained as explicit fail-closed signatures.
This prevents an unresolved call graph while avoiding fabricated tables or
columns.

## Privilege boundary

All retired signatures and both reconciled functions explicitly revoke
execution from `PUBLIC`, `anon`, and `authenticated`. The reviewed
`marino_secure_rpc` and `marino_admin_rpc` gateways remain the only client
entry points. Every `SECURITY DEFINER` body uses the fixed
`pg_catalog, public` search path.

## Data and behavior preservation

Migration `202607140004_legacy_function_schema_reconciliation.sql` creates no
table or column and performs no user-row `INSERT`, `UPDATE`, or `DELETE` while
being applied. The admin function retains its pending-request status update
using the real review timestamp. Poker keeps its live economy and outcome body
byte-for-byte except for how its transaction-local temporary relation is
addressed.

## Rollback

Before permanent application, the migration body is executed in a production
transaction, all twelve target functions are linted using the cataloged
`plpgsql_check` API, and the transaction is rolled back. Function definitions,
ACLs, and critical table row counts are compared before and after rollback.
The permanent migration is forward-only; automatic production restore is not
part of this procedure. The verified custom-format backup is the recovery
source if separately authorized.
