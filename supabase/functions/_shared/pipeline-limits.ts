export const SCRAPE_DEADLINE_MS = 7 * 60_000;
export const FOLLOWUP_DEADLINE_MS = 5 * 60_000;
export const MAX_POLL_FAILURES = 6;
export const MAX_MAPBOX_REQUESTS_PER_RUN = 10;

export function hasProcessingBudget(
  deadlineMs: number,
  nowMs = Date.now(),
): boolean {
  return nowMs < deadlineMs;
}

export function canUseMapbox(
  used: number | null | undefined,
  cap = MAX_MAPBOX_REQUESTS_PER_RUN,
): boolean {
  return Math.max(0, used ?? 0) < cap;
}

export function needsActorAbort(component: {
  status: string;
  error?: string | null;
  apify_run_id?: string | null;
}): boolean {
  if (!component.apify_run_id) return false;
  return component.status === "pending" || component.status === "running" ||
    (component.error ?? "").startsWith("cancel_abort_pending:");
}

export function elapsedMs(
  startedAt: string | null | undefined,
  nowMs = Date.now(),
): number {
  const start = Date.parse(startedAt ?? "");
  return Number.isFinite(start) ? Math.max(0, nowMs - start) : 0;
}

export function deadlineExceeded(
  startedAt: string | null | undefined,
  deadlineMs: number,
  nowMs = Date.now(),
): boolean {
  const start = Date.parse(startedAt ?? "");
  return Number.isFinite(start) && nowMs - start >= deadlineMs;
}

export function actorAbortUrl(runId: string): string {
  return `https://api.apify.com/v2/actor-runs/${
    encodeURIComponent(runId)
  }/abort`;
}
