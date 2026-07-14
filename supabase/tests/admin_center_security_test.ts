import { assert, assertEquals } from "jsr:@std/assert@1";

const root = new URL("../migrations/", import.meta.url);
const read = (name: string) => Deno.readTextFile(new URL(name, root));
const canonical = await read("202607150008_canonical_admin_center.sql");
const gateway = await read("202607150009_admin_management_gateway.sql");
const announcements = await read("202607150010_live_announcements.sql");

Deno.test("new admin security-definer functions pin search_path", () => {
  for (const sql of [canonical, gateway, announcements]) {
    for (const block of sql.matchAll(/create or replace function[\s\S]*?\$\$;/gi)) {
      if (/security definer/i.test(block[0])) assert(/set search_path = pg_catalog, public/i.test(block[0]));
    }
  }
});

Deno.test("client roles can execute only authenticated gateways", () => {
  assert(/revoke all on function public\.marino_admin_gateway\(text,jsonb,uuid\) from public,anon/i.test(gateway));
  assert(/revoke all on function public\.marino_announcement_player_rpc\(text,jsonb,uuid\) from public,anon/i.test(announcements));
  assert(/revoke all on function public\.marino_announcement_admin_rpc\(text,jsonb,uuid\) from public,anon/i.test(announcements));
  assertEquals((canonical.match(/grant execute on function public\.marino_bootstrap_owner\(text\) to service_role/g) || []).length, 1);
});

Deno.test("announcement player response excludes authority and targeting internals", () => {
  const active = announcements.match(/if p_action='active_announcements'[\s\S]*?elsif p_action in/)?.[0] || "";
  assert(active.includes("public.marino_announcement_is_targeted"));
  for (const forbidden of ["published_by", "created_by", "updated_by", "target_rules", "telegram_id"]) assert(!active.includes(`a.${forbidden}`));
});
