import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url:
          'https://vlkfmraxbpwctukymsyt.supabase.co', // Replace with your Supabase project URL
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsa2ZtcmF4YnB3Y3R1a3ltc3l0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNDY5NTE0MywiZXhwIjoyMDUwMjcxMTQzfQ.E-PHg7JyjwLmQBe9fZ0ToXlNLsKXSsxnLzJWeOZSXjM',
    );
  }
}
