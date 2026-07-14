import { assert, assertEquals } from "jsr:@std/assert@1";

const sql = await Deno.readTextFile(new URL("../migrations/202607140006_social_chat_and_gifts.sql", import.meta.url));

Deno.test("SQL filter normalizes and never stores a raw message", () => {
  assert(sql.includes("normalize(p_text, NFKC)"));
  assert(sql.includes("[iletişim bilgisi gizlendi]"));
  assert(!/raw_body|unfiltered_body|original_message/i.test(sql));
});

Deno.test("contact bypass corpus is represented in server checks", () => {
  const expected = ["whatsapp", "instagram", "discord", "snapchat", "facebook", "twitter", "telegram_username", "sıfır", "translate(v_fold, 'oıl', '011')"];
  assertEquals(expected.filter((marker) => !sql.includes(marker)), []);
});

Deno.test("anonymous history payload excludes direct identity fields", () => {
  const match = sql.match(/jsonb_build_object\('id',m\.id,'alias',sp\.public_alias[\s\S]*?'own',m\.sender_auth_user_id=v_user\.auth_user_id\)/);
  assert(match);
  assert(!/telegram_id|display_name|email|player_id/.test(match[0]));
});
