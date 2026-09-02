/// <reference path="../_shared/deno.d.ts" />
import { createClient } from "jsr:@supabase/supabase-js@2";
import { isAdminRequest } from "../_shared/auth.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchWithTimeout } from "../_shared/http.ts";
import { actorAbortUrl, needsActorAbort } from "../_shared/pipeline-limits.ts";

const ACTIVE = ["pending", "running"];
const ABORT_PENDING = "cancel_abort_pending:";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return jsonResponse({ error: "Use POST" }, 405);
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  if (!(await isAdminRequest(req, supabase))) {
    return jsonResponse({ error: "admin_required" }, 403);
  }
  const body = await req.json().catch(() => ({})) as { run_id?: unknown };
  if (typeof body.run_id !== "string" || !body.run_id) {
    return jsonResponse({ error: "run_id_required" }, 400);
  }

  const { data: run, error } = await supabase.from("scrape_runs").select(
    "id,status",
  ).eq("id", body.run_id).maybeSingle();
  if (error) return jsonResponse({ error: error.message }, 500);
  if (!run) return jsonResponse({ error: "run_not_found" }, 404);
  const now = new Date().toISOString();
  const message = "Cancelled by administrator";
  if (ACTIVE.includes(run.status)) {
    const { error: claimError } = await supabase.from("scrape_runs").update({
      status: "failed",
      error: message,
      completed_at: now,
    })
      .eq("id", run.id).in("status", ACTIVE);
    if (claimError) return jsonResponse({ error: claimError.message }, 500);
  }

  const token = Deno.env.get("APIFY_TOKEN");
  let aborted = 0;
  for (let pass = 0; pass < 2; pass++) {
    const { data, error: componentError } = await supabase.from(
      "scrape_run_components",
    )
      .select("id,apify_run_id,status,error").eq("scrape_run_id", run.id);
    if (componentError) {
      return jsonResponse({ error: componentError.message }, 500);
    }
    const candidates = (data ?? []).filter((component) =>
      ACTIVE.includes(component.status) ||
      String(component.error ?? "").startsWith(ABORT_PENDING)
    );
    await Promise.all(candidates.map(async (component) => {
      if (!component.apify_run_id) {
        // It may be between the paid actor start response and publication of
        // its ID. Keep it retryable; the worker will either publish+abort or
        // close it after observing the terminal run.
        await supabase.from("scrape_run_components").update({
          error: `${ABORT_PENDING} awaiting actor publication`,
        }).eq("id", component.id);
        return;
      }
      if (!token) {
        await supabase.from("scrape_run_components").update({
          error: `${ABORT_PENDING} APIFY_TOKEN unavailable`,
        }).eq("id", component.id);
        return;
      }
      try {
        const response = await fetchWithTimeout(
          `${actorAbortUrl(component.apify_run_id)}?gracefully=true`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${token}` },
          },
          10_000,
        );
        if (!response.ok) {
          throw new Error(`Apify abort returned ${response.status}`);
        }
        aborted++;
        await supabase.from("scrape_run_components").update({
          status: "failed",
          error: `${message}; actor abort accepted`,
          completed_at: now,
        }).eq("id", component.id);
      } catch (abortError) {
        await supabase.from("scrape_run_components").update({
          error: `${ABORT_PENDING} ${
            abortError instanceof Error
              ? abortError.message
              : String(abortError)
          }`,
        }).eq("id", component.id);
      }
    }));
  }

  const { data: remaining, error: remainingError } = await supabase.from(
    "scrape_run_components",
  )
    .select("id,apify_run_id,status,error").eq("scrape_run_id", run.id);
  if (remainingError) {
    return jsonResponse({ error: remainingError.message }, 500);
  }
  const pending = (remaining ?? []).filter((component) =>
    ACTIVE.includes(component.status) || needsActorAbort(component)
  );
  const cancelled = pending.length === 0;
  return jsonResponse({
    run_id: run.id,
    status: "failed",
    cancelled,
    retry_required: !cancelled,
    pending_actor_aborts: pending.length,
    actors_aborted: aborted,
  }, cancelled ? 200 : 202);
});
