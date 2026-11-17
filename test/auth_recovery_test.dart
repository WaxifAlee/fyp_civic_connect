import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/auth/auth_layout.dart';
import 'package:fyp_civic_connect/features/auth/forgot_screen.dart';
import 'package:fyp_civic_connect/features/auth/login_screen.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';

class OfflineAuth extends AuthService {
  @override
  Future<void> sendPasswordReset(String email) async =>
      throw FirebaseAuthException(code: 'network-request-failed');
}

class PendingAuth extends AuthService {
  final result = Completer<UserCredential>();
  @override
  Future<UserCredential> signIn(String email, String password) => result.future;
}

class Credential extends Fake implements UserCredential {
  @override
  User get user => Citizen();
}

class Citizen extends Fake implements User {
  @override
  bool get emailVerified => false;
}

void main() {
  testWidgets('offline password reset offers retry instead of claiming receipt',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: ForgotScreen(authService: OfflineAuth())));
    await tester.enterText(find.byType(TextFormField), 'citizen@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your inbox'), findsNothing);
    expect(find.textContaining('connection'), findsWidgets);
    expect(find.text('Send reset link'), findsOneWidget);
  });

  testWidgets('a disabled auth back action cannot leave an operation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: AuthLayout(
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
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: LoginScreen(authService: auth)));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'citizen@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), ' Password123! ');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
    auth.result.complete(Credential());
    await tester.pumpAndSettle();
    expect(AppSession.instance.isPreview, isTrue);
    expect(tester.takeException(), isNull);
  });
}
