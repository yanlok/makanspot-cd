/// <reference path="./deno.d.ts" />
import { type SupabaseClient } from "jsr:@supabase/supabase-js@2";

function bearerToken(req: Request): string | null {
  const value = req.headers.get("Authorization") ?? "";
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

/** Validate a caller and its database-backed admin role. */
export async function isAdminRequest(
  req: Request,
  supabase: SupabaseClient,
): Promise<boolean> {
  // Trusted server-side automation uses the project service-role credential.
  // Human callers still require a database-backed admin profile below.
  if (await isServiceRoleRequest(req)) return true;

  const token = bearerToken(req);
  if (!token) return false;
  // These public endpoints are deployed with Supabase JWT verification on.
  // Decode the already-verified subject instead of depending on an anon-key
  // environment variable that is not present in every Edge deployment.
  const payloadSegment = token.split(".")[1];
  if (!payloadSegment) return false;
  let userId: string | null = null;
  try {
    const base64 = payloadSegment.replace(/-/g, "+").replace(/_/g, "/")
      .padEnd(Math.ceil(payloadSegment.length / 4) * 4, "=");
    const payload = JSON.parse(atob(base64)) as { sub?: string };
    userId = payload.sub ?? null;
  } catch {
    return false;
  }
  if (!userId) return false;

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  return !profileError && profile?.role === "admin";
}

async function sha256(value: string): Promise<Uint8Array> {
  const bytes = new TextEncoder().encode(value);
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

/** Compare digests so secret length/content are not leaked by early exits. */
export async function isServiceRoleRequest(req: Request): Promise<boolean> {
  const token = bearerToken(req) ?? "";
  const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!token || !expected) return false;
  const [actualDigest, expectedDigest] = await Promise.all([
    sha256(token),
    sha256(expected),
  ]);
  let difference = 0;
  for (let i = 0; i < actualDigest.length; i++) {
    difference |= actualDigest[i] ^ expectedDigest[i];
  }
  return difference === 0;
}
