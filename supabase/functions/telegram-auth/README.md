# Telegram authentication Edge Function

This function validates Telegram Mini App `initData` before creating an
in-memory Supabase Auth session. It never trusts `initDataUnsafe`.

Required function secrets:

- `TELEGRAM_BOT_TOKEN`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`
- `APP_ORIGIN` — exact production origin, without a trailing slash
- `TELEGRAM_INIT_DATA_MAX_AGE_SECONDS` — recommended value: `300`

`SUPABASE_URL` is provided by Supabase. Do not put any of these values in the
repository or public frontend.

Before deployment, set the project JWT expiry to 15 minutes, enable refresh
token rotation/reuse detection, and deploy this function with JWT verification
disabled only for this endpoint. The Telegram HMAC validation is the endpoint's
bootstrap authentication; all other functions must retain normal JWT checks.

The function is not deployed by this branch. Deployment and secret provisioning
are manual production operations described in `docs/security/P0_RUNBOOK.md`.
