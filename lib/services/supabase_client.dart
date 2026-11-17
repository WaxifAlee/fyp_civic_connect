import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool _initialized = false;
  static bool get isConfigured => _initialized;
  static Future<void> initialize() async {
    if (url.isEmpty || anonKey.isEmpty || _initialized) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
    _initialized = true;
  }
}
