import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export type AdminAuthSuccess = {
  ok: true;
  adminEmail: string | null;
};

export type AdminAuthFailure = {
  ok: false;
  status: 401 | 403 | 500;
  message: string;
};

export type AdminAuthResult = AdminAuthSuccess | AdminAuthFailure;

/**
 * Validates the caller via Supabase Auth JWT and `public.is_admin()`.
 * Email is informational only; membership in `admin_users` is authoritative.
 */
export async function requireAdmin(req: Request): Promise<AdminAuthResult> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !/^Bearer\s+/i.test(authHeader)) {
    return {
      ok: false,
      status: 401,
      message: "Authorization header required",
    };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return {
      ok: false,
      status: 500,
      message: "Server auth configuration missing",
    };
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: isAdmin, error: rpcError } = await userClient.rpc("is_admin");
  if (rpcError) {
    console.warn("catalog-yml-import-manual: is_admin RPC failed", rpcError.message);
    return { ok: false, status: 403, message: "Admin access denied" };
  }

  const allowed = isAdmin === true || isAdmin === 1 || isAdmin === "true" ||
    isAdmin === "t";
  if (!allowed) {
    return { ok: false, status: 403, message: "Admin access denied" };
  }

  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  let adminEmail: string | null = null;
  try {
    const { data: userData, error: userError } = await userClient.auth.getUser(
      token,
    );
    if (!userError && userData.user?.email) {
      adminEmail = userData.user.email;
    }
  } catch {
    // Non-fatal — metadata can omit email.
  }

  return { ok: true, adminEmail };
}
