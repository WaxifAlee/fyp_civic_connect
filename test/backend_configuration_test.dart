import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';

void main() {
  test('client configuration rejects privileged or malformed keys', () {
    String token(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({
              'role': role
            })))}.signature';
    expect(SupabaseService.isPublicClientKey(token('anon')), isTrue);
    expect(SupabaseService.isPublicClientKey(token('service_role')), isFalse);
    expect(SupabaseService.isPublicClientKey('sb_secret_example'), isFalse);
    expect(SupabaseService.isPublicClientKey('sb_publishable_local_example'),
        isTrue);
    expect(SupabaseService.isPublicClientKey('malformed'), isFalse);
  });
  test('live startup rejects missing public backend configuration', () async {
    expect(SupabaseService.isConfigured, isFalse);
    await expectLater(SupabaseService.initialize(), throwsStateError);
    expect(SupabaseService.isConfigured, isFalse);
  });

  test('auth links accept only the registered callback origin', () {
    expect(
        SupabaseService.isAuthCallback(
            Uri.parse('io.supabase.civicconnect://auth-callback/?code=example'),
            isWeb: false),
        isTrue);
    expect(
        SupabaseService.isAuthCallback(
            Uri.parse('https://unrelated.example/?code=example'),
            isWeb: false),
        isFalse);
    expect(
        SupabaseService.isAuthCallback(
            Uri.parse('io.supabase.civicconnect://other/?code=example'),
            isWeb: false),
        isFalse);
    expect(
        SupabaseService.isAuthCallback(
            Uri.parse('https://civic.example/?code=example'),
            isWeb: true,
            webOrigin: 'https://civic.example'),
        isTrue);
    expect(
        SupabaseService.isAuthCallback(
            Uri.parse('https://evil.example/?code=example'),
            isWeb: true,
            webOrigin: 'https://civic.example'),
        isFalse);
    expect(
        SupabaseService.isAuthCallback(Uri.parse('https://civic.example/'),
            isWeb: true, webOrigin: 'https://civic.example'),
        isFalse);
  });
}
