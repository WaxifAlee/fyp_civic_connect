import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:fyp_civic_connect/features/reports/presentation/report_issue_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'report_submission_recovery_test.dart' show MemoryReportBackend, submit;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.leavePreview();
  });

  Future<MemoryReportBackend> saveUnknownSubmission() async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    await expectLater(submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()));
    return backend;
  }

  Future<void> openRecovery(
      WidgetTester tester, MemoryReportBackend backend) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: ReportIssueScreen(
          submission: ReportSubmissionService(backend: backend)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('restart recovery works with empty form and no photos',
      (tester) async {
    final backend = await saveUnknownSubmission();
    backend.hideLookup = false;
    await openRecovery(tester, backend);
    expect(find.text('Saved submissions'), findsOneWidget);
    await tester.ensureVisible(find.text('Recover saved submission'));
    await tester.tap(find.text('Recover saved submission'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MC00001'), findsWidgets);
    expect(find.text('Report submitted'), findsNothing);
    expect(find.text('Describe the issue in at least 5 characters.'),
        findsNothing);
    expect(find.text('Add between 1 and 3 photos to continue.'), findsNothing);
    expect(backend.creates, hasLength(1));
    expect(backend.uploads, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final deleted in [false, true]) {
    testWidgets('recovery keeps a partially edited draft, deleted: $deleted',
        (tester) async {
      final backend = await saveUnknownSubmission();
      backend
        ..hideLookup = false
        ..deleted = deleted;
      await openRecovery(tester, backend);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'New draft title');
      await tester.enterText(find.byType(TextFormField).at(1), 'Still writing');
      await tester.ensureVisible(find.text('Recover saved submission'));
      await tester.tap(find.text('Recover saved submission'));
      await tester.pumpAndSettle();
      final fields =
          tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[0].controller!.text, 'New draft title');
      expect(fields[1].controller!.text, 'Still writing');
      expect(find.text('Report submitted'), findsNothing);
      expect(find.text('Recover saved submission'), findsNothing);
      if (deleted) {
        expect(
            find.text(
                'Earlier report was removed; submit your current draft when ready.'),
            findsOneWidget);
      } else {
        expect(find.textContaining('MC00001'), findsWidgets);
      }
      expect(backend.creates, hasLength(1));
      expect(backend.removals, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('panel updates the count and recovers requests one at a time',
      (tester) async {
    final backend = await saveUnknownSubmission();
    backend
      ..loseCreateResponse = false
      ..createGate = Completer<void>();
    await openRecovery(tester, backend);
    await tester.ensureVisible(find.text('Recover saved submission'));
    await tester.tap(find.text('Recover saved submission'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    final original =
        jsonDecode(prefs.getString(prefs.getKeys().single)!) as Map;
    const otherId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final other = Map<String, dynamic>.from(original)
      ..['requestId'] = otherId
      ..['payload'] = {...original['payload'] as Map, 'p_request_id': otherId};
    await prefs.setString(
        'reports.pending_submission.v2.${backend.uid}.$otherId',
        jsonEncode(other));
    backend.createGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('1 saved submission to check.'), findsOneWidget);
    expect(find.text('Recover saved submission'), findsOneWidget);
    await tester.ensureVisible(find.text('Recover saved submission'));
    await tester.tap(find.text('Recover saved submission'));
    await tester.pumpAndSettle();
    expect(find.text('Recover saved submission'), findsNothing);
    expect(backend.creates.last['p_request_id'], otherId);
    expect(backend.uploads, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery cannot start a second submission while confirming',
      (tester) async {
    final backend = await saveUnknownSubmission();
    backend
      ..loseCreateResponse = false
      ..createGate = Completer<void>();
    await openRecovery(tester, backend);
    await tester.ensureVisible(find.text('Recover saved submission'));
    await tester.tap(find.text('Recover saved submission'));
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(
                OutlinedButton, 'Checking saved submission…'))
            .onPressed,
        isNull);
    backend.createGate!.complete();
    await tester.pumpAndSettle();
    expect(backend.creates, hasLength(2));
    expect(backend.uploads, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
