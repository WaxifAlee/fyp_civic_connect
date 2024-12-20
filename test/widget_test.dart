// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(CivicConnectApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Welcome screen displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(CivicConnectApp());

    expect(find.text('Report Issues Easily'), findsOneWidget);
    expect(find.text('Stay Informed'), findsOneWidget);
    expect(find.text('Improve Your Community'), findsOneWidget);
  });

  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(CivicConnectApp());
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In to Your Account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Signup screen displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(CivicConnectApp());
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    expect(find.text('Register an Account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(8));
  });
}
