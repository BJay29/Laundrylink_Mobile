import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase client setup — must be initialized ONCE in
/// main() before runApp(), and before anything (like
/// BookingRealtimeService) touches Supabase.instance.client.
///
/// SUPABASE_URL and SUPABASE_ANON_KEY here are the PUBLIC anon key
/// pair — the same one the web/mobile Auth flow already uses. This is
/// safe to ship in the app; it is NOT the service_role key (that one
/// lives only on the backend, in supabase_storage.py's env vars, and
/// must never appear in client code).
///
/// Usage (in main.dart):
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await SupabaseConfig.initialize();
///   runApp(const MyApp());
/// }
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  // TODO: replace with your actual Supabase project URL and anon key
  // (Project Settings -> API in the Supabase Dashboard).
  static const String supabaseUrl = 'https://twbqutjesxkpxklmhsxh.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_5Y6U8-7T-FDxez-3BbcCaA_yDg-5zD8';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _initialized = true;
  }

  /// Convenience getter so other files can write
  /// `SupabaseConfig.client` instead of `Supabase.instance.client`
  /// everywhere — purely cosmetic, both refer to the same instance.
  static SupabaseClient get client => Supabase.instance.client;
}