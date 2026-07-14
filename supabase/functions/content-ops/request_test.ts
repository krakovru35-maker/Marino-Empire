import { mapAction, safeError } from "./request.ts";

function assert(condition: unknown, message = "assertion failed"): asserts condition { if (!condition) throw new Error(message); }
const requestId = "00000000-0000-4000-8000-000000000001";
const contentId = "00000000-0000-4000-8000-000000000002";

Deno.test("player answer maps only allowlisted fields", () => {
  const mapped = mapAction("submit_answer", { content_id: contentId, answer: "test", request_id: requestId, role: "super_admin" });
  assert(mapped.rpc === "submit_daily_content_answer");
  assert(!("p_role" in mapped.params));
});

Deno.test("unknown action and invalid request id fail closed", () => {
  try { mapAction("unknown", {}); throw new Error("expected rejection"); } catch (error) { assert(String(error).includes("action_not_allowed")); }
  try { mapAction("claim_reward", { content_id: contentId, request_id: "bad" }); throw new Error("expected rejection"); } catch (error) { assert(String(error).includes("request_id_invalid")); }
});

Deno.test("errors never expose exception messages", () => {
  const result = safeError({ code: "XX000", message: "sensitive database detail" });
  assert(result.error === "request_rejected");
  assert(!JSON.stringify(result).includes("sensitive"));
});
