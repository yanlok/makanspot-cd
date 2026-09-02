/// Fetch with a hard wall-clock timeout. The caller may provide a signal; both
/// signals are honoured and the timer is always released.
export async function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit = {},
  timeoutMs = 15_000,
): Promise<Response> {
  const timeout = AbortSignal.timeout(Math.max(1, timeoutMs));
  const signal = init.signal
    ? AbortSignal.any([init.signal, timeout])
    : timeout;
  return await fetch(input, { ...init, signal });
}

export function timeoutMsFromEnv(name: string, fallback: number): number {
  const parsed = Number(Deno.env.get(name));
  return Number.isFinite(parsed) && parsed > 0 ? Math.trunc(parsed) : fallback;
}
