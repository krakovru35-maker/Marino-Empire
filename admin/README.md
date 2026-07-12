# Admin security architecture

The previous static admin console was removed from `public/`. A privileged
console must never be shipped as part of the GitHub Pages artifact.

## Required architecture

1. Host the admin console separately from the public game.
2. Sign administrators in with Supabase Auth. Require MFA before any privileged
   operation.
3. Store authorization in `marino_admin_roles`, keyed by `auth.users.id`.
   Never accept an admin id, Telegram id, role, or authorization flag from the
   browser.
4. Call only the `marino_admin_rpc(action, payload)` gateway. The gateway derives
   the caller from `auth.uid()`, checks an active role, records an audit event,
   validates the payload, and only then calls a legacy admin function.
5. Keep the old admin functions revoked from `PUBLIC`, `anon`, and
   `authenticated`. They remain callable only inside the trusted gateway.
6. Provision and revoke admin roles through a documented break-glass process
   using the Supabase Dashboard or a service-role-only backend. Never expose the
   service-role key to the browser.

The database objects are prepared by the P0 migrations under
`supabase/migrations/`. Applying them is intentionally a separate, manual
production operation.
