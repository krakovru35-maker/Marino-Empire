# Legacy gameplay baseline security review

Date: 2026-07-14

Scope: repository-external, schema-only production `public` export and the
derived `202607110001_legacy_gameplay_baseline.sql`. No database write, user-row
read, function deployment, migration repair or staging operation was performed.

## Raw export safety gate

The raw dump remained outside the repository and is not tracked. Context-aware
scanning distinguished DDL/function bodies from table data and found:

- zero top-level `COPY` statements;
- zero top-level `INSERT INTO` statements;
- zero `auth.users` data statements;
- zero e-mail or Telegram-ID row values;
- zero secret-key, service-role or JWT-secret patterns;
- zero connection URI or database-password patterns;
- zero function bodies containing e-mail, long numeric identity or secret
  literals.

The baseline contains no dump meta-commands, schema owner statements, production
rows, managed `auth`/`storage` schema definitions or connection material. It
contains 74 installable function overloads; five stale production overloads are
inventoried below but excluded because their referenced public tables do not
exist in the canonical export.

## Canonical public inventory

Production schema-only inventory:

- 24 tables
- 17 owned sequences
- 0 custom types/enums
- 0 views or materialized views
- 50 constraints, including 12 foreign keys
- 10 explicit indexes
- 0 triggers
- 24 RLS-enabled tables
- 9 permissive production policies
- 79 function overloads (76 unique names)
- 66 `SECURITY DEFINER` overloads

### Tables

- `marino_achievements`
- `marino_ad_reward_logs`
- `marino_buildings`
- `marino_daily_cipher`
- `marino_daily_combo`
- `marino_daily_login`
- `marino_player_achievements`
- `marino_player_boosts`
- `marino_player_buildings`
- `marino_player_seasons`
- `marino_player_tasks`
- `marino_players`
- `marino_processed_requests`
- `marino_reward_requests`
- `marino_seasons`
- `marino_sink_purchases`
- `marino_sports_coupons`
- `marino_sports_matches`
- `marino_sports_players`
- `marino_sports_teams`
- `marino_store_items`
- `marino_task_claims`
- `marino_tasks`
- `marino_wallets`

### Function overloads

Core helpers/state:

- `_marino_ensure_boost(text)`
- `_marino_next_cost(bigint,integer)`
- `_marino_recalc_income(text)`
- `_marino_refresh_energy(text)`
- `_marino_rpc_id(text)`
- `_marino_seed_buildings(text)`
- `_marino_seed_store()`
- `_marino_state(text)`
- `calc_building_cost(bigint,numeric,integer)`
- `get_game_state(text)`
- `marino_bootstrap(text)`
- `marino_building_income(integer,numeric,numeric)`
- `marino_income_per_hour(text)`
- `marino_level_from_rep(numeric)`
- `marino_recalculate_income(text)`
- `marino_state(text)`
- `marino_sync_player(text)`
- `marino_touch_state(text)`
- `marino_upgrades(text)`
- `marino_upgrades_json(text)`
- `start_game(text,text,text,text,text,text)`
- `register_player(text,text,text,text,text,text)`
- `register_player(text,text,text,text,text,text,text)`
- `sync_leaderboard(text)`

Economy/progression/tasks/rewards:

- `tap_coin(text,integer)`
- `collect_income(text,text)`
- `upgrade_building(text,text,text)`
- `request_reward(text,text,text)`
- `marino_buy_sink(text,text,text)`
- `marino_claim_ad_reward(text,text)`
- `marino_claim_daily_login(text,text)`
- `marino_claim_referral(text,text,text)`
- `marino_claim_task(text,text,integer)`
- `marino_claim_task(text,text,integer,text)`
- `marino_prestige(text,text)`
- `marino_upgrade_capacity(text,text)`
- `marino_upgrade_tap(text,text)`
- `marino_reward_status(text)`
- `marino_store_json()`
- `marino_save_settings(text,text,text,boolean,boolean,text)`

Daily/boost/wallet:

- `marino_get_today_combo()`
- `marino_get_today_cipher()`
- `marino_claim_combo(text,text[])`
- `marino_claim_cipher(text,text)`
- `marino_hk_state(text)`
- `marino_get_boosts(text)`
- `marino_use_full_energy(text)`
- `marino_use_tap_boost(text)`
- `marino_upgrade_multitap(text)`
- `marino_upgrade_energy_limit(text)`
- `marino_activate_auto_tap(text)`
- `marino_airdrop_status(text)`
- `marino_connect_wallet(text,text)`

Casino/sports/social:

- `marino_buy_chips(text,bigint)`
- `marino_play_slot(text,bigint,text)`
- `marino_play_mini_game(text,text,text)`
- `marino_play_roulette(text,bigint,text,text)`
- `marino_play_roulette_v2(text,jsonb,text)`
- `marino_bj_score(jsonb)`
- `marino_bj_deal(text,bigint)`
- `marino_bj_hit(text)`
- `marino_bj_stand(text)`
- `marino_random_card()`
- `marino_play_horse_racing(text,integer,integer)`
- `marino_play_poker(text,integer)`
- `marino_generate_matches(integer)`
- `marino_get_live_matches()`
- `marino_place_sports_bet(text,uuid,text,bigint)`
- `marino_play_virtual_sports(text,text,bigint,text)`
- `marino_get_leaderboard(text,text,integer,integer)`
- `marino_get_referrals(text)`
- `marino_check_coupons(text)`
- `marino_get_my_notifications(text)`

Legacy admin:

- `marino_admin_get_users(text)`
- `marino_admin_get_requests(text)`
- `marino_admin_update_user(text,text,bigint,bigint,integer)`
- `marino_admin_toggle_ban(text,text)`
- `marino_admin_resolve_request(text,integer,text)`
- `marino_admin_resolve_request(text,integer,text,text)`

### Excluded stale production functions

These functions are present in production metadata but are not called by
`marino_secure_rpc` or `marino_admin_rpc` and reference public relations absent
from the same canonical export:

- `marino_income_per_hour(text)` references missing
  `public.marino_building_defs`.
- `marino_state(text)` calls the excluded `marino_income_per_hour(text)`.
- `marino_sync_player(text)` references missing
  `public.marino_building_defs`.
- `marino_upgrades(text)` references missing
  `public.marino_building_defs`.
- `sync_leaderboard(text)` references missing `public.users`,
  `public.player_state` and `public.leaderboard`.

No dummy relations or replacement bodies were invented. Removing these five
unreachable stale definitions leaves zero unresolved `public.*` references in
the baseline and does not remove a gateway dependency.

## Security differences from production export

Function bodies were compared by exact signature after newline and trailing-whitespace normalization:
all 74 included production bodies are present and unchanged. Therefore reward,
price, energy, chip, coin, bet and payout behavior has not been deliberately
altered by the baseline.

Only these security boundaries differ:

1. All 64 included `SECURITY DEFINER` overloads set
   `search_path = pg_catalog, public`. Production definitions either omitted a
   search path or used a public-only setting.
2. All 24 tables, 17 sequences and 74 function overloads are explicitly revoked
   from `PUBLIC`, `anon` and `authenticated` at creation time. P0 migrations later
   expose only reviewed authenticated gateways.
3. Nine production policies using unconditional `USING (true)` were omitted:
   reward-request admin read/update, public player read, and broad RPC policies
   on daily login, achievements, buildings, seasons, tasks and processed requests.
   Every table remains RLS-enabled with deny-by-default direct client access.
4. Raw dump schema creation/comments, pg_dump controls and owner-specific
   statements are not included.
5. `marino_connect_wallet(text,text)` is preserved for canonical compatibility
   but remains non-executable by client roles. Wallet functionality stays closed.

The dump contained no explicit function ACL override statements. Regardless of
whether production relied on PostgreSQL's default `PUBLIC EXECUTE`, the baseline
closes execution explicitly.

## Gateway signature reconciliation

The canonical export exposed four incompatibilities in the prepared P0 gateways:

- leaderboard is `(text,text,integer,integer)`, not a three-integer overload;
- sports match ID is UUID, not bigint;
- horse-racing and poker bet inputs are integer, not bigint;
- admin reward-request ID is integer, not bigint.

The gateway now validates/casts to those exact signatures. Bet values are already
bounded to at most 1,000,000 before integer narrowing, so this compatibility fix
does not change the canonical economy calculation. The sports ID validation now
matches the canonical UUID primary key. The generic privilege sweep remains;
three redundant direct function revokes were removed because the baseline and
sweep both close those functions.

Static dependency analysis confirms that every legacy function invoked by
`marino_secure_rpc` and `marino_admin_rpc` exists in the baseline with the
required canonical overload.

## Migration order

1. `202607110001_legacy_gameplay_baseline.sql`
2. `202607120001_p0_identity_roles_rls.sql`
3. `202607120002_p0_function_privileges.sql`
4. `202607120003_p0_secure_rpc.sql`
5. `202607120004_p0_admin_gateway.sql`
6. `202607120005_p0_auth_bootstrap_rate_limit.sql`
7. `202607120006_p0_auth_bootstrap_lease.sql`
8. `202607140001_content_operations_schema.sql`
9. `202607140002_content_operations_rpc.sql`
10. `202607140003_content_admin_reporting.sql`

## Remaining validation blockers

- Docker/local Supabase is unavailable, so PostgreSQL has not executed the clean
  chain from an empty database.
- Catalog-level compilation, effective ACL/RLS and pgTAP assertions must run on
  an isolated empty database.
- Telegram Auth and authenticated gameplay/admin gateway flows require staging
  sessions after a separate clean-staging write approval.
- Claim concurrency still requires a real two-session database test.
- The current staging project has a partial history (`202607120001` only) and
  must not be repaired forward. Recreate it cleanly after explicit approval.
