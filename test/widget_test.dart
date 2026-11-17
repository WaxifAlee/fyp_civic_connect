import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/main.dart';
import 'package:fyp_civic_connect/features/reports/presentation/map_location_picker.dart';

Future<void> openScreen(WidgetTester tester, String route,
    {Size size = const Size(1440, 1100),
    double scale = 1,
    bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  AppSession.instance.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
  await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: CivicConnectApp(initialRoute: route)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('PublicSans')
      ..addFont(rootBundle.load('assets/fonts/PublicSans.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.enterPreview();
  });

  testWidgets('welcome provides sign-in and explicit sample workspace entry',
      (tester) async {
    AppSession.instance.leavePreview();
    await openScreen(tester, '/welcome');
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Explore the demo'));
    await tester.pumpAndSettle();
    expect(AppSession.instance.isPreview, isTrue);
    expect(find.text('Demo workspace · Sample data'), findsOneWidget);
    expect(find.text('Your recent reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login validates locally without contacting authentication',
      (tester) async {
    await openScreen(tester, '/login');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone navigation opens explore and query retains status filter',
      (tester) async {
    await openScreen(tester, '/dashboard', size: const Size(375, 900));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Explore your community'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'road');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Submitted'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Submitted'));
    await tester.pumpAndSettle();
    expect(find.text('Damaged road surface on Hospital Road'), findsOneWidget);
    expect(find.text('Footpath needs repair near the school'), findsNothing);
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Open drain cover beside the bus stop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report details open and close with accessible controls',
      (tester) async {
    await openScreen(tester, '/my_reports');
    await tester.tap(find.text('Streetlight out near the main market'));
    await tester.pumpAndSettle();
    expect(find.text('Report details'), findsOneWidget);
    expect(find.text('What’s happening'), findsOneWidget);
    await tester.tap(find.byTooltip('Close report details'));
    await tester.pumpAndSettle();
    expect(find.text('Report details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification empty state links to actual reports',
      (tester) async {
    await openScreen(tester, '/notifications');
    expect(find.textContaining('caught up'), findsOneWidget);
    expect(find.textContaining('My reports'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling deletion keeps the report detail open',
      (tester) async {
    await openScreen(tester, '/my_reports');
    await tester.tap(find.text('Streetlight out near the main market'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete my report'));
    await tester.tap(find.text('Delete my report'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keep report'));
    await tester.pumpAndSettle();
    expect(find.text('Report details'), findsOneWidget);
  });

  testWidgets(
      'large text remains usable inside report details and account editing',
      (tester) async {
    await openScreen(tester, '/my_reports',
        size: const Size(375, 900), scale: 2, dark: true);
    await tester
        .ensureVisible(find.text('Streetlight out near the main market'));
    await tester.tap(find.text('Streetlight out near the main market'));
    await tester.pumpAndSettle();
    expect(find.text('Report details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await openScreen(tester, '/profile',
        size: const Size(375, 900), scale: 2, dark: true);
    await tester.ensureVisible(find.text('Edit details'));
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration second step supports large text without submitting',
      (tester) async {
    await openScreen(tester, '/signUp', size: const Size(375, 900), scale: 2);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ayesha Khan');
    await tester.enterText(fields.at(1), 'ayesha@example.com');
    await tester.enterText(fields.at(2), 'Example123!');
    await tester.enterText(fields.at(3), 'Example123!');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('A little about you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual location remains usable with large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark, home: const MapLocationPicker(isPreview: true)));
    await tester.pumpAndSettle();
    expect(find.text('Confirm location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exiting a demo retries real service initialization',
      (tester) async {
    await openScreen(tester, '/dashboard');
    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle();
    expect(AppSession.instance.isPreview, isFalse);
    // No Firebase plugin is initialized in widget tests. Bootstrap must expose retry.
    expect(find.text('We couldn’t get connected'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  for (final route in [
    '/dashboard',
    '/explore',
    '/report_issue',
    '/my_reports',
    '/profile',
    '/welcome',
    '/login',
    '/signUp',
    '/reset_password',
    '/change_password'
  ]) {
    testWidgets('$route supports a small phone and large text in dark mode',
        (tester) async {
      await openScreen(tester, route,
          size: const Size(375, 900), scale: 2, dark: true);
      expect(tester.takeException(), isNull);
      final scrollable = find.byType(Scrollable).first;
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('overview adapts to tablet landscape with reduced motion',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openScreen(tester, '/dashboard', size: const Size(1024, 768));
    expect(find.text('Your recent reports'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('CAPTURE_UI')) {
    for (final view in [
      (
        route: '/dashboard',
        name: 'overview-desktop',
        size: const Size(1440, 1100),
        dark: false
      ),
      (
        route: '/dashboard',
        name: 'overview-phone',
        size: const Size(375, 1000),
        dark: false
      ),
      (
        route: '/explore',
        name: 'explore-desktop',
        size: const Size(1440, 1100),
        dark: false
      ),
      (
        route: '/report_issue',
        name: 'report-desktop',
        size: const Size(1440, 1100),
        dark: false
      ),
      (
        route: '/profile',
        name: 'account-dark',
        size: const Size(1440, 1100),
        dark: true
      ),
      (
        route: '/welcome',
        name: 'welcome-desktop',
        size: const Size(1440, 1100),
        dark: false
      ),
    ]) {
      testWidgets('capture ${view.name}', (tester) async {
        await openScreen(tester, view.route, size: view.size, dark: view.dark);
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('/tmp/civic-connect-previews/${view.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
