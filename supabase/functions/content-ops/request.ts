export const PLAYER_ACTIONS = Object.freeze({
  get_active: { rpc: "get_active_daily_content", fields: ["language"] },
  submit_answer: { rpc: "submit_daily_content_answer", fields: ["content_id", "answer", "request_id"] },
  claim_reward: { rpc: "claim_daily_content_reward", fields: ["content_id", "request_id"] },
});

export const ADMIN_ACTIONS = Object.freeze({
  admin_list: { rpc: "admin_get_daily_content", fields: [] },
  admin_audit: { rpc: "admin_get_content_audit", fields: ["limit"] },
  admin_upsert: { rpc: "admin_upsert_daily_content", fields: ["content_id", "document", "answer", "expected_version", "request_id"] },
  admin_publish: { rpc: "admin_publish_daily_content", fields: ["content_id", "expected_version", "request_id"] },
  admin_cancel: { rpc: "admin_cancel_daily_content", fields: ["content_id", "expected_version", "request_id"] },
});
const ACTIONS: Record<string, { rpc: string; fields: readonly string[] }> = { ...PLAYER_ACTIONS, ...ADMIN_ACTIONS };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function mapAction(action: unknown, input: Record<string, unknown>) {
  const definition = ACTIONS[String(action)];
  if (!definition) throw new Error("action_not_allowed");
  const params: Record<string, unknown> = {};
  for (const field of definition.fields) {
    const value = input[field];
    if (field === "request_id" && !UUID.test(String(value ?? ""))) throw new Error("request_id_invalid");
    if (field === "content_id" && value != null && !UUID.test(String(value))) throw new Error("content_id_invalid");
    if (field === "answer" && (typeof value !== "string" || value.length < 1 || value.length > 512)) throw new Error("answer_invalid");
    params[`p_${field}`] = value ?? null;
  }
  return { rpc: definition.rpc, params };
}

export function safeError(error: unknown) {
  const code = typeof error === "object" && error && "code" in error ? String((error as { code: unknown }).code) : "request_rejected";
  const known = new Set(["42501", "P0001", "23505", "22023"]);
  return { error: known.has(code) ? code : "request_rejected" };
}
