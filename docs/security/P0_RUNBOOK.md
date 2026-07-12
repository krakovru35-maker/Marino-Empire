# P0 security hardening runbook

These changes are prepared but deliberately not applied to Supabase or deployed.

## Change inventory

- `public/admin.html` removed from the GitHub Pages artifact.
- Pages workflow fails if a static admin/password pattern returns to `public/`.
- `admin/README.md` defines the Supabase Auth + MFA + trusted-role architecture.
- `supabase/functions/telegram-auth/` validates signed Telegram `initData` and
  creates a non-persistent Supabase Auth session.
- `public/index.html` requires that verified session and routes calls through
  `marino_secure_rpc`.
- Economic offline fallbacks and client-generated wallet state were removed.
- SQL migrations add identity links, admin roles/audit, idempotency, RLS,
  privilege revocation, fixed `search_path`, gameplay gateway and admin gateway.

## SECURITY DEFINER inventory in this repository

The original migration contains these definer functions:

1. `marino_claim_combo(text,text[])`
2. `marino_claim_cipher(text,text)`
3. `_marino_ensure_boost(text)`
4. `marino_get_boosts(text)`
5. `marino_use_full_energy(text)`
6. `marino_use_tap_boost(text)`
7. `marino_upgrade_multitap(text)`
8. `marino_upgrade_energy_limit(text)`
9. `marino_activate_auto_tap(text)`
10. `marino_connect_wallet(text,text)`
11. `marino_airdrop_status(text)`
12. `marino_hk_state(text)`

The P0 migrations additionally create tightly scoped helper/gateway functions.
Migration `202607120002` dynamically finds all production `marino_*` and core
game functions, revokes direct client execution, and fixes `search_path` on
every definer function it finds.

## Mandatory preflight before applying SQL

Take a database backup and test on a restored staging project first. Run these
read-only queries in staging/production to compare live function signatures with
the compatibility calls in `202607120003` and `202607120004`:

```sql
select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
       p.prosecdef, p.proconfig
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.proname like 'marino_%' or p.proname in
       ('start_game','tap_coin','collect_income','upgrade_building','request_reward'))
order by p.proname, pg_get_function_identity_arguments(p.oid);

select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public' and tablename like 'marino_%'
order by tablename;
```

Do not apply if any legacy signature differs from the wrapper call. Adjust the
wrapper in source, repeat staging tests, review the diff, then apply.

## Manual Supabase configuration

1. Create a staging clone/restore and apply migrations there in filename order.
2. Set Auth JWT expiry to 900 seconds.
3. Enable refresh-token rotation and reuse detection.
4. Confirm anonymous sign-ins are disabled; the Edge Function creates managed
   users through the service role.
5. Add Edge Function secrets listed in
   `supabase/functions/telegram-auth/README.md`. Never place their values in Git.
6. Configure `APP_ORIGIN` to the exact GitHub Pages production origin.
7. Deploy only `telegram-auth` with bootstrap JWT verification disabled. Keep JWT
   verification enabled for every other Edge Function.
8. Provision the first admin by inserting an existing, MFA-enabled Auth user UUID
   into `marino_admin_roles` through the Dashboard/service-role process. Do not
   accept a UUID or role from a browser request.
9. Confirm no client has `EXECUTE` on legacy/admin/answer functions.
10. Run the staged authorization matrix below before scheduling production.

No `supabase db push`, `db reset`, `migration up`, SQL Editor execution, function
deployment, secret update or Pages deployment is performed by this branch.

## Required staged tests

- Invalid, altered, expired and replayed Telegram payloads are rejected.
- A valid Telegram payload creates a session mapped to exactly one Telegram ID.
- A user cannot pass another `telegram_id` through the gateway.
- `anon` cannot execute any legacy game, admin, Combo-answer or Cipher-answer RPC.
- `authenticated` can execute only `marino_secure_rpc`, identity helpers and the
  admin gateway; admin actions still fail without an active trusted role.
- Support/operator/security-admin permissions match the documented matrix.
- Duplicate request UUIDs return the stored result or fail while in progress.
- Negative, zero, over-limit and malformed bets/amounts/identifiers fail.
- Supabase/network failure never awards coin, boost, wallet or airdrop state.
- The public Pages artifact contains no admin console.

## Rollback plan

Rollback is operational, not automatic:

1. Stop traffic or place the game in maintenance mode.
2. Restore the pre-change database backup if any migration caused data or function
   incompatibility. This is the safest rollback for replaced privileges/functions.
3. Alternatively, restore the captured preflight function ACLs and `proconfig`
   settings, then drop only the new gateways/tables after confirming they contain
   no required audit/identity records.
4. Revert the P0 application commit on its branch and redeploy the last known-good
   Pages artifact only after the database rollback is complete.
5. Revoke sessions created during the failed rollout and rotate affected secrets.

Do not use `db reset`; it would destroy data.

## Remaining risks

- Live legacy function definitions are not stored in this repository. Gateway
  compatibility must be proven against staging before apply.
- Password-based managed Auth users are an implementation bridge. A dedicated
  signed custom-token service can replace it later.
- The wallet flow is intentionally disabled until TonConnect signature validation
  is implemented.
- Existing dynamic `innerHTML` usage remains an XSS risk outside this P0 scope.
- The publishable Supabase configuration remains public by design; security now
  depends on RLS, ACLs and verified sessions, which require staged validation.
- Rate limiting, replay storage for Telegram `query_id`, MFA enrollment UI and a
  separately hosted admin console remain follow-up work.
