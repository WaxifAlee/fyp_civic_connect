import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_session.dart';
import '../utils/validators.dart';
import 'supabase_client.dart';

/// Supabase authentication boundary. Pending email lives only in process memory.
class AuthService {
  const AuthService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  static String? _pendingEmail;

  SupabaseClient get client => _providedClient ?? Supabase.instance.client;

  User? get currentUser {
    if (_providedClient == null && !SupabaseService.isConfigured) {
      return null;
    }
    return client.auth.currentUser;
  }

  Session? get currentSession {
    if (_providedClient == null && !SupabaseService.isConfigured) {
      return null;
    }
    return client.auth.currentSession;
  }

  String? get pendingVerificationEmail => _pendingEmail;

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _pendingEmail =
          response.user?.emailConfirmedAt == null ? email.trim() : null;
      return response;
    } on AuthException catch (error) {
      if (error.code == 'email_not_confirmed') _pendingEmail = email.trim();
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String cnic,
    required String location,
    required String gender,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseService.authRedirectUrl,
      data: {
        'full_name': fullName.trim(),
        'phone': Validators.normalizePhone(phone),
        'cnic': cnic.trim(),
        'locations': location.trim(),
        'gender': gender,
      },
    );
    _pendingEmail = email.trim();
    return response;
  }

  Future<void> resendVerification() async {
    final email = _pendingEmail ?? currentUser?.email;
    if (email == null || email.isEmpty) throw AuthSessionMissingException();
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: SupabaseService.authRedirectUrl,
    );
  }

  Future<User?> refreshUser() async {
    if (currentSession == null) {
      return null;
    }
    final pending = _pendingEmail;
    if (pending != null &&
        currentUser?.email?.toLowerCase() != pending.toLowerCase()) {
      return null;
    }
    // Refresh also replaces the SDK's cached user and JWT after confirmation.
    return (await client.auth.refreshSession()).user;
  }

  Future<void> sendPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email.trim(),
          redirectTo: SupabaseService.authRedirectUrl);

  Future<void> updatePassword(String password) async {
    if (AppSession.instance.isPreview || currentSession == null) {
      throw AuthSessionMissingException();
    }
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() async {
    if (currentSession != null) await client.auth.signOut();
    _pendingEmail = null;
  }
}
