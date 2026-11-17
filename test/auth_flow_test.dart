import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/features/auth/auth_flow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('invalid credentials offer a sign-in correction without backend detail',
      () {
    final message = friendlyAuthError(const AuthException(
      'private backend detail',
      code: 'invalid_credentials',
    ));
    expect(message, contains('email and password'));
    expect(message, isNot(contains('private backend detail')));
  });

  test('retryable auth transport failure offers connection recovery', () {
    expect(
      friendlyAuthError(AuthRetryableFetchException(message: 'private URL')),
      contains('connection'),
    );
  });

  test('missing own profile retains actionable retry guidance', () {
    expect(
      friendlyAuthError(const PostgrestException(
        message: 'private row details',
        code: 'PGRST116',
      )),
      contains('profile is missing'),
    );
  });

  test('database errors never expose identity constraints or server details',
      () {
    final message = friendlyAuthError(const PostgrestException(
      message: 'duplicate cnic 12345-1234567-1',
      code: '23505',
    ));
    expect(message, isNot(contains('12345')));
    expect(message, contains('details'));
  });

  test('request timeouts offer connection recovery', () {
    expect(friendlyAuthError(TimeoutException('private endpoint')),
        contains('connection'));
  });
}
