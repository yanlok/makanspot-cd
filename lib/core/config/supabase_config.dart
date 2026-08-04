/// Supabase backend configuration.
///
/// Values are hard-coded so the app connects without extra build flags.
/// The anon key is a public client credential — paste your project's key
/// below (Supabase Dashboard → Project Settings → API → Project API keys →
/// anon public).
///
/// Until `supabaseAnonKey` is filled in, `isConfigured` is false and the
/// app falls back to the in-memory fixture repository so it still runs
/// without a backend.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String supabaseUrl = 'https://npmdrgpypkozdjtiplmf.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wbWRyZ3B5cGtvemRqdGlwbG1mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2Njg3NDAsImV4cCI6MjEwMDI0NDc0MH0.2-73aK_GKwNBPsW4bzlMp98yT6PXo83fxQBv4J3_ZmE';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
