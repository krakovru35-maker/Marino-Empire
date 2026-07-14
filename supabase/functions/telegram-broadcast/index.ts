import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function safeMessage(value: unknown) {
  const text = String(value ?? "").trim();
  if (text.length < 2 || text.length > 800) throw new Error("message_invalid");
  return text.replace(/[\u0000-\u001f\u007f]/g, " ");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });

  const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!token || !supabaseUrl || !serviceRoleKey) return json(503, { ok: false, error: "broadcast_not_configured" });

  const authHeader = request.headers.get("Authorization") ?? "";
  const bearer = authHeader.replace(/^Bearer\s+/i, "");
  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
  const { data: userResult, error: userError } = await client.auth.getUser(bearer);
  if (userError || !userResult.user) return json(401, { ok: false, error: "authentication_required" });

  const { data: admin, error: adminError } = await client.rpc("marino_admin_me");
  const canSend = admin?.role === "super_admin" || (admin?.permissions ?? []).includes("notifications.send");
  if (adminError || !admin?.is_admin || !canSend) {
    return json(403, { ok: false, error: "notifications_permission_required" });
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json(400, { ok: false, error: "invalid_json" });
  }

  let message: string;
  try {
    message = safeMessage(body.message);
  } catch {
    return json(400, { ok: false, error: "message_invalid" });
  }

  const dryRun = body.dry_run !== false;
  const limit = Math.min(Math.max(Number(body.limit ?? 100), 1), 1000);
  const { data: players, error: playerError } = await serviceClient
    .from("marino_players")
    .select("telegram_id")
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (playerError) return json(500, { ok: false, error: "recipient_query_failed" });

  const recipients = (players ?? []).map((row) => String(row.telegram_id)).filter((id) => /^[1-9][0-9]{2,32}$/.test(id));
  if (dryRun) return json(200, { ok: true, dry_run: true, recipients: recipients.length });

  let sent = 0;
  let failed = 0;
  for (const chatId of recipients) {
    const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text: message, disable_web_page_preview: true }),
    });
    if (response.ok) sent += 1;
    else failed += 1;
  }

  return json(200, { ok: true, dry_run: false, sent, failed });
});
