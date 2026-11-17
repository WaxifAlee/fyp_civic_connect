import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/auth/signup_screen.dart';
import 'package:fyp_civic_connect/features/auth/verification_waiting_screen.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupAuth extends AuthService {
  String? submittedEmail;
  int resends = 0;
  int refreshes = 0;
  bool offline = false;
  Completer<AuthResponse>? pending;

  @override
  String? get pendingVerificationEmail => submittedEmail;
  @override
  User? get currentUser => null;
  @override
  Session? get currentSession => null;
  @override
  Future<AuthResponse> signUp(
      {required String email,
      required String password,
      required String fullName,
      required String phone,
      required String cnic,
      required String location,
      required String gender}) async {
    submittedEmail = email.trim();
    if (pending != null) return pending!.future;
    // Supabase intentionally obscures duplicate confirmed registrations.
    return AuthResponse(
        user: const User(
            id: 'obscured-user',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            email: 'citizen@example.com',
            createdAt: '2026-11-17T00:00:00Z',
            identities: []));
  }

  @override
  Future<void> resendVerification() async {
    if (offline) throw AuthRetryableFetchException();
    resends++;
  }

  @override
  Future<User?> refreshUser() async {
    refreshes++;
    return null;
  }

  @override
  Future<void> signOut() async {}
}

Widget app(SignupAuth auth, {bool verification = false}) => MaterialApp(
      theme: AppTheme.light,
      home: verification
          ? VerificationWaitingScreen(authService: auth)
          : SignupScreen(authService: auth),
      routes: {
        '/verification': (_) => VerificationWaitingScreen(authService: auth),
        '/login': (_) => const Scaffold(body: Text('Sign-in destination')),
      },
    );

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
}

Future<void> completeSignup(WidgetTester tester) async {
  await enter(tester, 'Full name', 'Citizen Example');
  await enter(tester, 'Email address', 'citizen@example.com');
  await enter(tester, 'Password', 'Password123!');
  await enter(tester, 'Confirm password', 'Password123!');
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await enter(tester, 'Phone number', '+923001234567');
  await enter(tester, 'CNIC', '12345-1234567-1');
  await enter(tester, 'Location / address', 'Fateh Jang');
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Other').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.ensureVisible(find.text('Create account'));
  await tester.tap(find.text('Create account'));
  await tester.pump();
}

void main() {
  setUp(() => AppSession.instance.leavePreview());
  tearDown(() => AppSession.instance.leavePreview());

  testWidgets(
      'empty signup identities lead to neutral inbox and sign-in guidance',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = SignupAuth();
    await tester.pumpWidget(app(auth));
    await completeSignup(tester);
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('already have an account'), findsOneWidget);
    expect(find.text('Sign in after confirming your email'), findsOneWidget);
    expect(find.text('citizen@example.com'), findsOneWidget);
    expect(find.textContaining('account has been created'), findsNothing);
  });

  testWidgets('signup shows the Account photo instruction before submission',
      (tester) async {
    await tester.pumpWidget(app(SignupAuth()));
    await enter(tester, 'Full name', 'Citizen Example');
    await enter(tester, 'Email address', 'citizen@example.com');
    await enter(tester, 'Password', 'Password123!');
    await enter(tester, 'Confirm password', 'Password123!');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Add a profile photo from Account after verifying your email.'),
        findsOneWidget);
  });

  testWidgets(
      'no-session verification can resend and sign in after browser confirmation',
      (tester) async {
    final auth = SignupAuth()..submittedEmail = 'citizen@example.com';
    await tester.pumpWidget(app(auth, verification: true));
    await tester.ensureVisible(find.text('I’ve verified my email'));
    await tester.tap(find.text('I’ve verified my email'));
    await tester.pumpAndSettle();
    expect(find.textContaining('another browser'), findsOneWidget);
    await tester.ensureVisible(find.text('Resend verification email'));
    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    expect(auth.resends, 1);
    expect(find.textContaining('If confirmation is pending'), findsOneWidget);
    expect(find.textContaining('Resend available in'), findsOneWidget);
    await tester
        .ensureVisible(find.text('Sign in after confirming your email'));
    await tester.tap(find.text('Sign in after confirming your email'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in destination'), findsOneWidget);
  });

  testWidgets(
      'offline verification resend offers retry without claiming delivery',
      (tester) async {
    final auth = SignupAuth()
      ..submittedEmail = 'citizen@example.com'
      ..offline = true;
    await tester.pumpWidget(app(auth, verification: true));
    await tester.ensureVisible(find.text('Resend verification email'));
    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();
    expect(find.textContaining('connection'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.textContaining('If confirmation is pending'), findsNothing);
  });

  testWidgets('abandoned signup cannot leave a later preview session',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = SignupAuth()..pending = Completer<AuthResponse>();
    await tester.pumpWidget(app(auth));
    await completeSignup(tester);
    await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
    AppSession.instance.enterPreview();
    auth.pending!.complete(AuthResponse());
    await tester.pumpAndSettle();
    expect(AppSession.instance.isPreview, isTrue);
    expect(tester.takeException(), isNull);
  });
}
