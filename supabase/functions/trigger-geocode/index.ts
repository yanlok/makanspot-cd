/// <reference path="../_shared/deno.d.ts" />
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isAdminRequest } from "../_shared/auth.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const supabase = createClient(supabaseUrl, serviceKey);
  if (!(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }

  const body = req.method === "POST"
    ? await req.json().catch(() => ({}))
    : {};

  try {
    const resp = await fetch(
      `${supabaseUrl}/functions/v1/geocode-restaurants`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      },
    );

    const contentType = resp.headers.get("content-type") ?? "";
    const data = contentType.includes("application/json")
      ? await resp.json()
      : { message: await resp.text() };

    return jsonResponse(data, resp.status);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: message }, 500);
  }
});
