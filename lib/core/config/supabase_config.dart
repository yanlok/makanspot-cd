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
      'sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
