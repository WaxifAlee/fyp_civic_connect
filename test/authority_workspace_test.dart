import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/authority/data/authority_service.dart';
import 'package:fyp_civic_connect/features/authority/domain/authority_models.dart';
import 'package:fyp_civic_connect/features/authority/presentation/authority_workspace_screen.dart';

class NoAccess extends AuthorityService {
  @override
  Future<AuthorityAccess?> access() async => null;
}

class RefreshQueue extends AuthorityService {
  Completer<AuthorityPage>? pending;
  @override
  Future<AuthorityPage> queue(
          {String query = '',
          String? status,
          String? category,
          String sort = 'oldest',
          int page = 0}) =>
      pending?.future ??
      super.queue(
          query: query,
          status: status,
          category: category,
          sort: sort,
          page: page);
}

class LostResponse extends AuthorityService {
  final requests = <String>[];
  int queueCalls = 0;
  @override
  Future<AuthorityPage> queue(
      {String query = '',
      String? status,
      String? category,
      String sort = 'oldest',
      int page = 0}) {
    queueCalls++;
    return super.queue(
        query: query,
        status: status,
        category: category,
        sort: sort,
        page: page);
  }

  @override
  Future<void> publish(
      {required String id,
      required int version,
      required String status,
      required String note,
      required String requestId}) async {
    requests.add(requestId);
    await super.publish(
        id: id,
        version: version,
        status: status,
        note: note,
        requestId: requestId);
    if (requests.length == 1) {
      throw const AuthorityException('The update could not be confirmed.',
          uncertain: true);
    }
  }
}

class ReloadFailure extends AuthorityService {
  bool published = false;
  bool failed = false;
  @override
  Future<AuthorityDetail> detail(String id) async {
    if (published && !failed) {
      failed = true;
      throw const AuthorityException('History refresh failed.');
    }
    return super.detail(id);
  }

  @override
  Future<void> publish(
      {required String id,
      required int version,
      required String status,
      required String note,
      required String requestId}) async {
    await super.publish(
        id: id,
        version: version,
        status: status,
        note: note,
        requestId: requestId);
    published = true;
  }
}

class ChangedSession extends AuthorityService {
  String account = 'A';
  int publishes = 0;
  @override
  String get sessionId => account;
  @override
  Future<void> publish(
      {required String id,
      required int version,
      required String status,
      required String note,
      required String requestId}) async {
    publishes++;
    await super.publish(
        id: id,
        version: version,
        status: status,
        note: note,
        requestId: requestId);
  }
}

class VersionConflict extends AuthorityService {
  bool first = true;
  @override
  Future<void> publish(
      {required String id,
      required int version,
      required String status,
      required String note,
      required String requestId}) async {
    if (first) {
      first = false;
      throw const AuthorityException('Another team member updated this report.',
          conflict: true);
    }
    await super.publish(
        id: id,
        version: version,
        status: status,
        note: note,
        requestId: requestId);
  }
}

Future<void> openWorkspace(WidgetTester tester,
    {Size size = const Size(1440, 1100),
    double scale = 1,
    AuthorityService? service}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: MediaQuery(
          data:
              MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: AuthorityWorkspaceScreen(service: service))));
  await tester.pumpAndSettle();
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
  testWidgets('nonmember sees an access explanation and no report data',
      (tester) async {
    await openWorkspace(tester, service: NoAccess());
    expect(find.text('Service-team access required'), findsOneWidget);
    expect(find.text('Streetlight out near the main market'), findsNothing);
  });
  testWidgets('queue metrics filter server-backed status and reset',
      (tester) async {
    await openWorkspace(tester);
    await tester.tap(find.byKey(const ValueKey('metric-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Damaged road surface on Hospital Road'), findsOneWidget);
    expect(find.text('Streetlight out near the main market'), findsNothing);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Streetlight out near the main market'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'queue refresh preserves visible reports after a connection failure',
      (tester) async {
    final service = RefreshQueue();
    await openWorkspace(tester, service: service);
    service.pending = Completer<AuthorityPage>();
    await tester.tap(find.text('Refresh queue'));
    await tester.pump();
    expect(find.text('Streetlight out near the main market'), findsOneWidget);
    service.pending!.completeError(
        const AuthorityException('Could not refresh the queue.'));
    await tester.pumpAndSettle();
    expect(find.text('Streetlight out near the main market'), findsOneWidget);
    expect(find.text('Could not refresh the queue.'), findsOneWidget);
  });
  testWidgets(
      'authority editor protects unpublished notes and comment drafts on close',
      (tester) async {
    await openWorkspace(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('progress-note')));
    await tester.enterText(find.byKey(const ValueKey('progress-note')),
        'A note still being prepared.');
    await tester.pump();
    await tester.tap(find.byTooltip('Close service report'));
    await tester.pumpAndSettle();
    expect(find.text('Discard report changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('A note still being prepared.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('comment-draft')));
    await tester.enterText(find.byKey(const ValueKey('comment-draft')),
        'Keep this discussion draft too.');
    await tester.pump();
    await tester.tap(find.byTooltip('Close service report'));
    await tester.pumpAndSettle();
    expect(find.text('Discard report changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this discussion draft too.'), findsOneWidget);
  });
  testWidgets('editor validates a public note and saves committed progress',
      (tester) async {
    await openWorkspace(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    expect(find.text('Publish a service update'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    expect(find.text('Write at least 10 characters.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('progress-note')),
        'A repair crew is on its way.');
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    expect(find.text('A repair crew is on its way.'), findsOneWidget);
    expect(find.textContaining('Nothing was sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'unknown update outcome locks the draft and retries the same request',
      (tester) async {
    final service = LostResponse();
    await openWorkspace(tester, service: service);
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('progress-note')));
    await tester.enterText(find.byKey(const ValueKey('progress-note')),
        'The site has been inspected for this repair.');
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('progress-note')))
            .enabled,
        isFalse);
    await tester.tap(find.byTooltip('Close service report'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your last change'), findsOneWidget);
    await tester.tap(find.text('Return to report'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retry same update'));
    await tester.pumpAndSettle();
    expect(service.requests.length, 2);
    expect(service.requests.first, service.requests.last);
    expect(find.text('The site has been inspected for this repair.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history refresh retry clears an already acknowledged draft',
      (tester) async {
    await openWorkspace(tester, service: ReloadFailure());
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    const note = 'This acknowledged note must not become a new draft.';
    await tester.enterText(find.byKey(const ValueKey('progress-note')), note);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    expect(find.text('History refresh failed.'), findsOneWidget);
    await tester.tap(find.byTooltip('Reload latest report'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('progress-note')))
            .controller!
            .text,
        isEmpty);
    expect(find.text(note), findsOneWidget);
  });

  testWidgets('an account switch blocks publishing before the mutation',
      (tester) async {
    final service = ChangedSession();
    await openWorkspace(tester, service: service);
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('progress-note')),
        'A draft from the original account.');
    service.account = 'B';
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    expect(service.publishes, 0);
    expect(find.textContaining('Your session changed'), findsOneWidget);
  });

  testWidgets('conflict recovery preserves the unpublished note',
      (tester) async {
    await openWorkspace(tester, service: VersionConflict());
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    const note = 'Keep this unpublished repair plan after refreshing.';
    await tester.enterText(find.byKey(const ValueKey('progress-note')), note);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reload latest report'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('progress-note')))
            .controller!
            .text,
        note);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    expect(find.text(note), findsOneWidget);
  });

  testWidgets('reloading an uncertain update refreshes the queue',
      (tester) async {
    final service = LostResponse();
    await openWorkspace(tester, service: service);
    await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
    await tester.tap(find.byKey(const ValueKey('review-demo-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('progress-note')),
        'Refresh the queue after checking uncertain progress.');
    await tester.tap(find.widgetWithText(FilledButton, 'Publish update'));
    await tester.pumpAndSettle();
    final calls = service.queueCalls;
    await tester.tap(find.byTooltip('Reload latest report'));
    await tester.pumpAndSettle();
    expect(service.queueCalls, greaterThan(calls));
  });

  for (final (size, scale) in [
    (const Size(375, 812), 2.0),
    (const Size(900, 700), 1.5)
  ]) {
    testWidgets('workspace adapts to $size at $scale text scale',
        (tester) async {
      await openWorkspace(tester, size: size, scale: scale);
      await tester.ensureVisible(find.byKey(const ValueKey('review-demo-1')));
      await tester.tap(find.byKey(const ValueKey('review-demo-1')));
      await tester.pumpAndSettle();
      expect(find.text('Publish update').hitTestable(), findsOneWidget);
      expect(
          find.byTooltip('Close service report').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
