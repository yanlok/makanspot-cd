// Supabase-specific EdgeRuntime global. Deno itself supplies the Deno global.
export {};

declare global {
  const EdgeRuntime: {
    waitUntil(promise: Promise<unknown>): void;
  };
}
