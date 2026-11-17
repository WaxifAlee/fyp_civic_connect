import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/auth/auth_layout.dart';
import 'package:fyp_civic_connect/features/auth/forgot_screen.dart';
import 'package:fyp_civic_connect/features/auth/login_screen.dart';
import 'package:fyp_civic_connect/features/auth/recovery_screen.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const citizen = User(
  id: 'citizen-id',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'citizen@example.com',
  createdAt: '2026-11-17T00:00:00Z',
);

class OfflineAuth extends AuthService {
  @override
  Future<void> sendPasswordReset(String email) async =>
      throw AuthRetryableFetchException();
}

class PendingAuth extends AuthService {
  final result = Completer<AuthResponse>();
  @override
  Future<AuthResponse> signIn(String email, String password) => result.future;
}

class RecoveryAuth extends AuthService {
  String? updatedPassword;
  bool signedOut = false;
  bool offline = false;
  Completer<void>? pending;

  @override
  User? get currentUser => signedOut ? null : citizen;
  @override
  Session? get currentSession => signedOut
      ? null
      : Session(
          accessToken: 'test-access-token',
          tokenType: 'bearer',
          user: citizen,
          refreshToken: 'test-refresh-token',
        );
  @override
  Future<void> updatePassword(String password) async {
    if (offline) throw AuthRetryableFetchException();
    updatedPassword = password;
    await pending?.future;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

Widget app(Widget home) =>
    MaterialApp(theme: AppTheme.light, home: home, routes: {
      '/login': (_) => const Scaffold(body: Text('Sign-in destination'))
    });

Future<void> fillRecovery(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), ' Password123! ');
  await tester.enterText(find.byType(TextFormField).at(1), ' Password123! ');
  await tester.ensureVisible(find.text('Update password'));
  await tester.tap(find.text('Update password'));
  await tester.pump();
}

void main() {
  tearDown(() => AppSession.instance.leavePreview());

  testWidgets('offline password reset offers retry instead of claiming receipt',
      (tester) async {
    await tester.pumpWidget(app(ForgotScreen(authService: OfflineAuth())));
    await tester.enterText(find.byType(TextFormField), 'citizen@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your inbox'), findsNothing);
    expect(find.textContaining('connection'), findsWidgets);
    expect(find.text('Send reset link'), findsOneWidget);
  });

  testWidgets('a disabled auth back action cannot leave an operation',
      (tester) async {
    await tester.pumpWidget(app(AuthLayout(
        title: 'Signing in',
        description: 'Please wait',
        backEnabled: false,
        onBack: () => fail('Back must be disabled'),
        children: const [])));
    final button = tester.widget<IconButton>(find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Back'));
    expect(button.onPressed, isNull);
  });

  testWidgets('abandoned sign-in cannot replace the active preview session',
      (tester) async {
    final auth = PendingAuth();
    AppSession.instance.enterPreview();
    await tester.pumpWidget(app(LoginScreen(authService: auth)));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'citizen@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), ' Password123! ');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
    auth.result.complete(AuthResponse(user: citizen));
    await tester.pumpAndSettle();
    expect(AppSession.instance.isPreview, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery is safe before Supabase initialization',
      (tester) async {
    await tester.pumpWidget(app(const RecoveryScreen()));
    expect(find.textContaining('unavailable or has expired'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'recovery updates the exact password and ends the recovery session',
      (tester) async {
    final auth = RecoveryAuth();
    await tester.pumpWidget(app(RecoveryScreen(authService: auth)));
    await fillRecovery(tester);
    await tester.pumpAndSettle();
    expect(auth.updatedPassword, ' Password123! ');
    expect(auth.signedOut, isTrue);
    expect(find.text('Password updated'), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in destination'), findsOneWidget);
  });

  testWidgets('recovery without a session offers a fresh link through sign in',
      (tester) async {
    final auth = RecoveryAuth()..signedOut = true;
    await tester.pumpWidget(app(RecoveryScreen(authService: auth)));
    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in destination'), findsOneWidget);
  });

  testWidgets('failed recovery retains the form and offers connection retry',
      (tester) async {
    final auth = RecoveryAuth()..offline = true;
    await tester.pumpWidget(app(RecoveryScreen(authService: auth)));
    await fillRecovery(tester);
    await tester.pumpAndSettle();
    expect(find.text('Password updated'), findsNothing);
    expect(find.textContaining('connection'), findsWidgets);
    expect(auth.signedOut, isFalse);
  });

  testWidgets('abandoned recovery does not sign out a later session',
      (tester) async {
    final auth = RecoveryAuth()..pending = Completer<void>();
    await tester.pumpWidget(app(RecoveryScreen(authService: auth)));
    await fillRecovery(tester);
    await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
    AppSession.instance.enterPreview();
    auth.pending!.complete();
    await tester.pumpAndSettle();
    expect(auth.signedOut, isFalse);
    expect(AppSession.instance.isPreview, isTrue);
    expect(tester.takeException(), isNull);
  });
}
