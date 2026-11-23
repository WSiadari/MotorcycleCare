/// Supabase settings are passed at build time so keys stay out of the code:
///   flutter run --dart-define-from-file=supabase.json
/// Without them the app runs with the built-in demo data.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable key (or the legacy anon key). Never the secret/service_role key.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get useSupabase => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
