import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_comments_panel.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_filters_bar.dart';
import 'package:fyp_civic_connect/features/reports/domain/report_filters.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_card.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/features/reports/application/report_comments_controller.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('PublicSans')
          ..addFont(rootBundle.load('assets/fonts/PublicSans.ttf')))
        .load();
  });
  setUp(() => AppSession.instance.enterPreview());
  tearDown(() => AppSession.instance.leavePreview());
  testWidgets(
      'reattaching an existing discussion controller reveals its retained draft',
      (tester) async {
    final controller = ReportCommentsController(reportId: 'reattached-draft');
    addTearDown(controller.dispose);
    await controller.load();
    controller.updateDraft('A visible draft must match what will be posted.');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReportCommentsPanel(
                    reportId: controller.reportId, controller: controller)))));
    await tester.pumpAndSettle();
    final field =
        tester.widget<TextField>(find.byKey(const ValueKey('comment-draft')));
    expect(field.controller!.text, controller.draft);
    expect(field.controller!.text, isNotEmpty);
  });
  testWidgets(
      'actual report sheet keeps comment controls above the phone keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReportCard(
                    report: Report(
                        id: 'keyboard-report',
                        title: 'Keyboard location report',
                        description:
                            'A report with enough context to scroll before commenting.',
                        category: 'Municipal Corportaion',
                        status: 'pending',
                        location: '33.55, 72.63'))))));
    await tester.tap(find.text('Keyboard location report'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('comment-draft')));
    await tester.enterText(find.byKey(const ValueKey('comment-draft')),
        'Keep the comment controls reachable.');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    final viewport = find.descendant(
        of: find.byType(ReportDetails),
        matching: find.byType(SingleChildScrollView));
    expect(tester.getBottomLeft(viewport).dy, lessThanOrEqualTo(492));
    await tester.ensureVisible(find.text('Post comment'));
    await tester.pumpAndSettle();
    expect(
        tester
            .getBottomLeft(find.widgetWithText(FilledButton, 'Post comment'))
            .dy,
        lessThanOrEqualTo(492));
    await tester.tap(find.text('Post comment'));
    await tester.pumpAndSettle();
    expect(find.text('Demo comment added in this session.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'phone discussion posts and confirms own removal without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(375, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
            body: SingleChildScrollView(
                child: MediaQuery(
                    data:
                        const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: ReportCommentsPanel(
                            reportId: 'widget-comments')))))));
    await tester.pumpAndSettle();
    expect(find.text('No comments yet'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('comment-draft')),
        'Can a crew inspect this drain?');
    await tester.pump();
    await tester.ensureVisible(find.text('Post comment'));
    await tester.tap(find.text('Post comment'));
    await tester.pumpAndSettle();
    expect(find.text('Can a crew inspect this drain?'), findsOneWidget);
    expect(find.text('Demo comment added in this session.'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Remove your comment'));
    await tester.tap(find.byTooltip('Remove your comment'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this comment?'), findsOneWidget);
    await tester.tap(find.text('Remove comment'));
    await tester.pumpAndSettle();
    expect(find.text('No comments yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Explore filters start compact and apply from a sheet',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final search = TextEditingController(text: 'drain');
    addTearDown(search.dispose);
    ReportStatus? chosen;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: ReportFiltersBar(
                search: search,
                category: null,
                status: null,
                sort: ReportSort.newest,
                onSearchChanged: (_) {},
                onReset: () {},
                onChanged: (category, status, sort) => chosen = status))));
    expect(tester.getSize(find.byType(ReportFiltersBar)).height, lessThan(90));
    expect(find.text('All categories'), findsNothing);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show reports'));
    await tester.pumpAndSettle();
    expect(chosen, ReportStatus.inProgress);
    expect(search.text, 'drain');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'enlarged phone filter reset is staged and cancellation preserves choices',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final search = TextEditingController(text: 'drain');
    addTearDown(search.dispose);
    var callbacks = 0;
    String? chosenCategory;
    ReportStatus? chosenStatus;
    ReportSort? chosenSort;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReportFiltersBar(
                    search: search,
                    category: 'Municipal Corportaion',
                    status: ReportStatus.inProgress,
                    sort: ReportSort.oldest,
                    onSearchChanged: (_) {},
                    onReset: () {},
                    onChanged: (category, status, sort) {
                      callbacks++;
                      chosenCategory = category;
                      chosenStatus = status;
                      chosenSort = sort;
                    })))));
    await tester.tap(find.text('Filters · 3'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reset filters'));
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.text('All statuses'), findsOneWidget);
    expect(callbacks, 0);
    await tester.ensureVisible(find.byTooltip('Close filters'));
    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();
    expect(callbacks, 0);
    expect(find.text('Filters · 3'), findsOneWidget);
    await tester.tap(find.text('Filters · 3'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reset filters'));
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show reports'));
    await tester.tap(find.text('Show reports'));
    await tester.pumpAndSettle();
    expect(callbacks, 1);
    expect(chosenCategory, isNull);
    expect(chosenStatus, isNull);
    expect(chosenSort, ReportSort.newest);
    expect(search.text, 'drain');
    expect(tester.takeException(), isNull);
  });
}
