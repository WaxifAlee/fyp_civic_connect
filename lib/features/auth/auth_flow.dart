import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fyp_civic_connect/services/user_service.dart';

class AccountSetupException implements Exception {
  const AccountSetupException(this.message);
  final String message;
}

/// The auth.users trigger creates profiles atomically during signup.
Future<void> prepareVerifiedCitizen(User user) async {
  if (user.emailConfirmedAt == null) {
    throw const AccountSetupException('Verify your email to continue.');
  }
  await fetchAndSetCitizenUser(user.id);
}

String friendlyAuthError(Object error) {
  const connection =
      'We couldn’t connect. Check your internet connection and try again.';
  if (error is AccountSetupException) return error.message;
  if (error is TimeoutException || error is AuthRetryableFetchException) {
    return connection;
  }
  if (error is AuthSessionMissingException) {
    return 'Your session ended. Open a fresh email link or sign in again.';
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'We couldn’t sign you in with those details. Check your email and password.';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'Check your email address and registration details and try again.';
      case 'email_not_confirmed':
        return 'Verify your email using the link in your inbox, then sign in.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Check your inbox for any confirmation link, or sign in to your existing account.';
      case 'weak_password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'same_password':
        return 'Choose a password you haven’t used for this account.';
      case 'user_banned':
        return 'This account is unavailable. Contact the service administrator.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return 'There have been too many attempts. Please wait before trying again.';
      case 'session_not_found':
      case 'session_expired':
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'otp_expired':
      case 'bad_jwt':
        return 'Your session or email link expired. Request a fresh link or sign in again.';
      case 'signup_disabled':
      case 'email_provider_disabled':
        return 'Email sign-in is currently unavailable. Please try again later.';
      case 'unexpected_failure':
        return 'Your account details couldn’t be saved. Check your details or try again later.';
    }
    if (error.statusCode == '429') {
      return 'There have been too many attempts. Please wait before trying again.';
    }
    if (error.statusCode == '0' || error.statusCode == '503') {
      return connection;
    }
  }
  if (error is PostgrestException) {
    if (error.code == 'PGRST116') {
      return 'Your sign-in exists, but your citizen profile is missing. '
          'Try again later, or contact the service administrator.';
    }
    return 'Your account details couldn’t be saved or loaded. Check your details or try again later.';
  }
  // Browser, HTTP and socket failures have different types on each platform.
  final kind = error.runtimeType.toString();
  if (kind == 'SocketException' ||
      kind == 'ClientException' ||
      kind == 'HandshakeException') {
    return connection;
  }
  return 'Something interrupted this step. Please try again.';
}
