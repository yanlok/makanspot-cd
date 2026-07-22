// Ambient declaration so editors using the Node TypeScript server don't flag
// the Deno runtime global. At runtime (Supabase Edge Functions run on Deno)
// the real, fully-typed Deno global is provided by the platform.
export {};

declare global {
  // deno-lint-ignore no-var
  var Deno: {
    env: { get(key: string): string | undefined };
    serve: (handler: (req: Request) => Response | Promise<Response>) => void;
  };
}
