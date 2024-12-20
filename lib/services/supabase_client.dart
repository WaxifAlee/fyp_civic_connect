import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url:
          'https://vlkfmraxbpwctukymsyt.supabase.co', // Replace with your Supabase project URL
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsa2ZtcmF4YnB3Y3R1a3ltc3l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ2OTUxNDMsImV4cCI6MjA1MDI3MTE0M30.Ag86O_TiPm6vsGy4b76bA-9jDCrLrMn0IXDiiE-khMc', // Replace with your anon key
    );
  }
}
