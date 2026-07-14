import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { mapAction, safeError } from "./request.ts";

const allowedOrigin = Deno.env.get("APP_ORIGIN") ?? "";
const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" } });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!allowedOrigin || request.headers.get("origin") !== allowedOrigin) return json(403, { error: "origin_rejected" });
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return json(401, { error: "authentication_required" });
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > 16384) return json(413, { error: "request_too_large" });

  try {
    const body = await request.json() as { action?: unknown; input?: Record<string, unknown> };
    const { rpc, params } = mapAction(body.action, body.input ?? {});
    const url = Deno.env.get("SUPABASE_URL");
    const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!url || !publishableKey) return json(503, { error: "server_not_configured" });
    const client = createClient(url, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });
    const { data, error } = await client.rpc(rpc, params);
    if (error) return json(error.code === "42501" ? 403 : error.code === "P0001" ? 429 : 400, safeError(error));
    return json(200, { data });
  } catch (error) {
    return json(400, safeError(error));
  }
});
