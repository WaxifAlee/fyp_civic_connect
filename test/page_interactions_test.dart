import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/main.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_card.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/features/reports/data/report_comments_service.dart';

class LostCommentResponse extends ReportCommentsService {
  final requests = <String>[];
  @override
  Future<ReportComment> add(
      String reportId, String body, String requestId) async {
    requests.add(requestId);
    if (requests.length == 1) {
      throw const CommentsException(
          'The response was lost. Retry this comment.',
          uncertain: true);
    }
    return super.add(reportId, body, requestId);
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('PublicSans')
          ..addFont(rootBundle.load('assets/fonts/PublicSans.ttf')))
        .load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.enterPreview();
  });
  tearDown(() => AppSession.instance.leavePreview());

  testWidgets(
      'short and empty pages can be pulled to refresh without changing content',
      (tester) async {
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CivicPage(
      title: 'Empty queue',
      onRefresh: () {
        calls++;
        return pending.future;
      },
      children: const [Text('No reports yet')],
    ))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(find.text('No reports yet'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final route in ['/dashboard', '/explore', '/my_reports', '/authority']) {
    testWidgets('$route offers native refresh on its main scroll surface',
        (tester) async {
      await tester.pumpWidget(CivicConnectApp(initialRoute: route));
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  }

  testWidgets('reselecting the active phone tab returns the page to the top',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const CivicConnectApp(initialRoute: '/explore'));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
            of: find.byType(CivicPage), matching: find.byType(Scrollable))
        .first;
    final state = tester.state<ScrollableState>(scrollable);
    await tester.drag(scrollable, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(100));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(state.position.pixels, 0);
  });

  testWidgets(
      'search keyboard action dismisses keyboard and preserves the query',
      (tester) async {
    await tester.pumpWidget(const CivicConnectApp(initialRoute: '/explore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'road');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('road'), findsOneWidget);
  });

  testWidgets('report draft stays intact when a citizen cancels leaving a tab',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester
        .pumpWidget(const CivicConnectApp(initialRoute: '/report_issue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(
        find.byType(TextFormField).first, 'Streetlight near the school');
    await tester.pump();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Discard report draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Streetlight near the school'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.text('Explore your community'), findsOneWidget);
  });

  testWidgets(
      'detail close remains visible and asks before discarding a comment',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportCard(
                report: Report(
      id: 'guarded-discussion',
      title: 'Inspect the drain',
      description: 'A long public discussion.',
    )))));
    await tester.tap(find.text('Inspect the drain'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('comment-draft')));
    await tester.enterText(
        find.byKey(const ValueKey('comment-draft')), 'A useful detail to keep');
    await tester.pumpAndSettle();
    expect(
        find.byTooltip('Close report details').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close report details'));
    await tester.pumpAndSettle();
    expect(find.text('Discard comment draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('A useful detail to keep'), findsOneWidget);
    await tester.fling(find.text('Report details'), const Offset(0, 160), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Discard comment draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    // Barrier and Android Back use the same guard.
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('Discard comment draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard comment draft?'), findsOneWidget);
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetails), findsNothing);
  });

  testWidgets(
      'an unconfirmed comment cannot be dismissed and retries its original request',
      (tester) async {
    final service = LostCommentResponse();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        enableDrag: false,
                        builder: (_) => SizedBox(
                            height: 550,
                            child: ReportDetails(
                                report: Report(
                                    id: 'uncertain-close',
                                    title: 'Check this issue'),
                                commentsService: service))),
                    child: const Text('Open report'))))));
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('comment-draft')));
    await tester.enterText(find.byKey(const ValueKey('comment-draft')),
        'Please preserve this exact request.');
    await tester.pump();
    await tester.ensureVisible(find.text('Post comment'));
    await tester.tap(find.text('Post comment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close report details'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetails), findsOneWidget);
    expect(find.text('Discard comment draft?'), findsNothing);
    expect(find.text('Confirm your last change'), findsOneWidget);
    await tester.tap(find.text('Return to report'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetails), findsOneWidget);
    await tester.tap(find.text('Return to report'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry same comment'));
    await tester.tap(find.text('Retry same comment'));
    await tester.pumpAndSettle();
    expect(service.requests, hasLength(2));
    expect(service.requests[0], service.requests[1]);
    await tester.tap(find.byTooltip('Close report details'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetails), findsNothing);
  });

  testWidgets(
      'account edits survive a cancelled navigation and sign-out warns about changes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const CivicConnectApp(initialRoute: '/profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit details'));
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'),
        'Changed Citizen Name');
    await tester.pump();
    await tester.tap(find.text('Explore issues'));
    await tester.pumpAndSettle();
    expect(find.text('Discard account changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Changed Citizen Name'), findsOneWidget);
    await tester.ensureVisible(find.text('Leave preview'));
    await tester.tap(find.text('Leave preview'));
    await tester.pumpAndSettle();
    expect(find.text('Your demo edits will be discarded.'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Changed Citizen Name'), findsOneWidget);
  });

  testWidgets(
      'discarding a root page draft exits safely instead of removing the last route',
      (tester) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester
        .pumpWidget(const CivicConnectApp(initialRoute: '/report_issue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(
        find.byType(TextFormField).first, 'An unfinished report');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(platformCalls, contains('SystemNavigator.pop'));
    expect(tester.takeException(), isNull);
  });
}
