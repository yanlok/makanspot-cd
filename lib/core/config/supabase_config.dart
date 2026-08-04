/// Supabase backend configuration.
///
/// Credentials are intentionally **not** committed. Provide them either by
/// editing the two constants below or by passing them at build/run time:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon-key>
/// ```
///
/// When neither the constants nor the defines are set, `isConfigured` is false
/// and the app falls back to the in-memory fixture repository so it still
/// runs without a backend.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}