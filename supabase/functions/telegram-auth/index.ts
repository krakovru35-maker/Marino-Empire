import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import {
  BootstrapError,
  DuplicateIdentityEmailError,
  createMagicLinkSession,
  ensureIdentity,
  withBootstrapLease,
} from "./auth-bootstrap.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

const encoder = new TextEncoder();

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function toHex(bytes: Uint8Array) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}

async function hmac(key: CryptoKey | Uint8Array, value: string) {
  const cryptoKey = key instanceof CryptoKey
    ? key
    : await crypto.subtle.importKey(
      "raw",
      toArrayBuffer(key),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value)));
}

async function sha256(value: string) {
  return toHex(new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value))));
}

function sleep(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

function logMasked(entry: { event: string; status: number | null; code: string }) {
  console.error("telegram-auth security event", entry);
}

function isDuplicateEmailError(error: unknown) {
  const candidate = error as { code?: string };
  return candidate?.code === "email_exists" || candidate?.code === "user_already_exists";
}

type TelegramUser = {
  id: number;
  first_name: string;
  last_name?: string;
  username?: string;
  language_code?: string;
};

async function verifyInitData(initData: string, botToken: string) {
  if (!initData || initData.length > 16_384) throw new Error("invalid_init_data");

  const params = new URLSearchParams(initData);
  const receivedHash = params.get("hash")?.toLowerCase() ?? "";
  const authDate = Number(params.get("auth_date"));
  const now = Math.floor(Date.now() / 1000);
  const maxAge = Number(Deno.env.get("TELEGRAM_INIT_DATA_MAX_AGE_SECONDS") ?? "300");

  if (!/^[a-f0-9]{64}$/.test(receivedHash)) throw new Error("invalid_hash");
  if (!Number.isSafeInteger(authDate) || authDate > now + 30 || now - authDate > maxAge) {
    throw new Error("expired_init_data");
  }

  const checkString = [...params.entries()]
    .filter(([key]) => key !== "hash")
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");

  const webAppDataKey = await hmac(encoder.encode("WebAppData"), botToken);
  const expectedHash = toHex(await hmac(webAppDataKey, checkString));
  if (!constantTimeEqual(receivedHash, expectedHash)) throw new Error("invalid_signature");

  const userRaw = params.get("user");
  if (!userRaw) throw new Error("missing_user");
  const user = JSON.parse(userRaw) as TelegramUser;
  if (!Number.isSafeInteger(user.id) || user.id <= 0 || !user.first_name) throw new Error("invalid_user");

  return {
    user,
    startParam: params.get("start_param") ?? "",
    authDate,
    queryId: params.get("query_id") ?? null,
  };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  const origin = request.headers.get("origin") ?? "";
  const allowedOrigin = Deno.env.get("APP_ORIGIN") ?? "";
  if (!allowedOrigin || origin !== allowedOrigin) return json(403, { error: "origin_not_allowed" });

  try {
    const { initData } = await request.json();
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
    if (!supabaseUrl || !serviceRoleKey || !anonKey || !botToken) throw new Error("server_not_configured");

    const verified = await verifyInitData(String(initData ?? ""), botToken);
    const telegramId = String(verified.user.id);
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const queryHash = await sha256(
      verified.queryId ? `${telegramId}:${verified.queryId}` : `${telegramId}:${verified.authDate}`,
    );
    const { data: rateAllowed, error: rateError } = await admin.rpc(
      "marino_check_bootstrap_rate_limit",
      {
        p_telegram_id: telegramId,
        p_query_hash: queryHash,
        p_max_attempts: Number(Deno.env.get("AUTH_BOOTSTRAP_MAX_ATTEMPTS") ?? "10"),
        p_window_seconds: Number(Deno.env.get("AUTH_BOOTSTRAP_WINDOW_SECONDS") ?? "300"),
      },
    );
    if (rateError) throw rateError;
    if (!rateAllowed) throw new Error("bootstrap_rate_limited");

    const email = `telegram_${telegramId}@sessions.invalid`;
    const leaseToken = crypto.randomUUID();
    const identity = await withBootstrapLease(leaseToken, {
      acquire: async (token, leaseSeconds) => {
        const { data, error } = await admin.rpc("marino_acquire_auth_bootstrap_lease", {
          p_telegram_id: telegramId, p_lease_token: token, p_lease_seconds: leaseSeconds,
        });
        if (error) throw error;
        return data === true;
      },
      release: async (token) => {
        const { data, error } = await admin.rpc("marino_release_auth_bootstrap_lease", {
          p_telegram_id: telegramId, p_lease_token: token,
        });
        if (error) throw error;
        return data === true;
      },
      sleep,
      logMasked,
    }, async () => {
      const result = await ensureIdentity({
        findLink: async () => {
          const { data, error } = await admin.from("marino_identity_links")
            .select("auth_user_id").eq("telegram_id", telegramId).maybeSingle();
          if (error) throw error;
          return data?.auth_user_id ?? null;
        },
        createUser: async () => {
          const { data, error } = await admin.auth.admin.createUser({
            email,
            email_confirm: true,
            app_metadata: { auth_source: "telegram", telegram_id: telegramId },
            user_metadata: {
              first_name: verified.user.first_name,
              last_name: verified.user.last_name ?? "",
              username: verified.user.username ?? "",
            },
          });
          if (error) {
            if (isDuplicateEmailError(error)) throw new DuplicateIdentityEmailError();
            throw error;
          }
          if (!data.user) throw new BootstrapError("identity_creation_failed");
          return data.user.id;
        },
        insertLink: async (authUserId) => {
          const { error } = await admin.from("marino_identity_links").insert({
            auth_user_id: authUserId,
            telegram_id: telegramId,
            telegram_username: verified.user.username ?? null,
            display_name: [verified.user.first_name, verified.user.last_name].filter(Boolean).join(" "),
            last_verified_at: new Date().toISOString(),
          });
          if (error) throw error;
        },
        deleteUser: async (authUserId) => {
          const { error } = await admin.auth.admin.deleteUser(authUserId);
          if (error) throw error;
        },
        sleep,
        logMasked,
      });

      if (!result.createdThisRequest) {
        const { error: updateError } = await admin.auth.admin.updateUserById(result.authUserId, {
          app_metadata: { auth_source: "telegram", telegram_id: telegramId },
          user_metadata: {
            first_name: verified.user.first_name,
            last_name: verified.user.last_name ?? "",
            username: verified.user.username ?? "",
          },
        });
        if (updateError) throw updateError;
        const { error: touchError } = await admin.from("marino_identity_links").update({
          telegram_username: verified.user.username ?? null,
          display_name: [verified.user.first_name, verified.user.last_name].filter(Boolean).join(" "),
          last_verified_at: new Date().toISOString(),
        }).eq("auth_user_id", result.authUserId);
        if (touchError) throw touchError;
      }
      return result;
    });

    const sessionClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const signIn = await createMagicLinkSession({
      generateHashedToken: async () => {
        const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email });
        if (error) throw error;
        const tokenHash = data.properties?.hashed_token;
        if (!tokenHash) throw new BootstrapError("session_create_failed");
        return tokenHash;
      },
      verifyHashedToken: async (tokenHash) => {
        const { data, error } = await sessionClient.auth.verifyOtp({ token_hash: tokenHash, type: "magiclink" });
        if (error || !data.session) throw error ?? new BootstrapError("session_create_failed");
        return data;
      },
    });
    if (!identity.authUserId || !signIn.session) throw new BootstrapError("session_create_failed");

    return json(200, {
      access_token: signIn.session.access_token,
      refresh_token: signIn.session.refresh_token,
      expires_in: signIn.session.expires_in,
      user: {
        id: telegramId,
        first_name: verified.user.first_name,
        last_name: verified.user.last_name ?? "",
        username: verified.user.username ?? "",
        language_code: verified.user.language_code ?? "",
      },
      start_param: verified.startParam,
    });
  } catch (error) {
    const known = error instanceof BootstrapError ? error : null;
    console.error("telegram-auth rejected", {
      event: known?.telemetryCode ?? "authentication_failed",
      status: known?.httpStatus ?? null,
      code: known?.publicCode ?? "unknown",
    });
    const message = known?.publicCode ?? (error instanceof Error ? error.message : "authentication_failed");
    const status = known?.httpStatus ?? (message === "server_not_configured" ? 503 : message === "bootstrap_rate_limited" ? 429 : 401);
    return json(status, { error: status === 401 ? "authentication_failed" : known?.publicCode ?? "authentication_failed" });
  }
});
