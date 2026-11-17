import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_comments_panel.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_filters_bar.dart';
import 'package:fyp_civic_connect/features/reports/domain/report_filters.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('PublicSans')
          ..addFont(rootBundle.load('assets/fonts/PublicSans.ttf')))
        .load();
  });
  setUp(() => AppSession.instance.enterPreview());
  tearDown(() => AppSession.instance.leavePreview());
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
}
