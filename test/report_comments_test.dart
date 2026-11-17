import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/reports/application/report_comments_controller.dart';
import 'package:fyp_civic_connect/features/reports/data/report_comments_service.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsBackend extends ReportBackend {
  String? uid = 'citizen';
  final calls = <(String, Map<String, dynamic>)>[];
  Future<dynamic> Function(String, Map<String, dynamic>)? handle;
  @override
  bool get isConfigured => true;
  @override
  String? get verifiedUserId => uid;
  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    calls.add((name, params));
    if (handle != null) return handle!(name, params);
    if (name == 'list_report_comments') {
      return {'comments': <dynamic>[], 'hasMore': false};
    }
    if (name == 'delete_report_comment') {
      return {'id': params['p_comment_id'], 'deleted': true};
    }
    return comment(id: params['p_request_id'], body: params['p_body']);
  }
}

Map<String, dynamic> comment(
        {String id = 'comment', String body = 'Site flooded.'}) =>
    {
      'id': id,
      'reportId': 'report',
      'body': body,
      'authorName': 'Test Citizen',
      'createdAt': '2026-11-17T09:00:00.123456Z',
      'isMine': true,
    };

void main() {
  setUp(() => AppSession.instance.leavePreview());
  test('list is bounded and uses the exact server timestamp for its cursor',
      () async {
    final b = CommentsBackend();
    b.handle = (_, __) async => {
          'comments': [comment()],
          'hasMore': true
        };
    final service = ReportCommentsService(backend: b);
    final page = await service.list('report');
    await service.list('report', before: page.comments.last);
    expect(b.calls.last.$2, {
      'p_report_id': 'report',
      'p_limit': 20,
      'p_before_at': '2026-11-17T09:00:00.123456Z',
      'p_before_id': 'comment',
    });
  });
  test('invalid bodies never reach the backend; Unicode uses code points',
      () async {
    final b = CommentsBackend();
    final service = ReportCommentsService(backend: b);
    await expectLater(
        service.add('report', ' \n ', 'id'), throwsA(isA<CommentsException>()));
    await expectLater(service.add('report', 'x' * 1001, 'id'),
        throwsA(isA<CommentsException>()));
    expect(b.calls, isEmpty);
    final posted = await service.add('report', ' ${'🌳' * 1000} ', 'id');
    expect(posted.body.runes.length, 1000);
  });
  test('unverified sessions cannot read or mutate', () async {
    final b = CommentsBackend()..uid = null;
    final s = ReportCommentsService(backend: b);
    await expectLater(s.list('report'), throwsA(isA<CommentsException>()));
    await expectLater(
        s.add('report', 'Hello', 'id'), throwsA(isA<CommentsException>()));
    await expectLater(
        s.remove('report', 'id'), throwsA(isA<CommentsException>()));
    expect(b.calls, isEmpty);
  });
  test('changed sessions discard a completed post', () async {
    final b = CommentsBackend();
    final gate = Completer<dynamic>();
    b.handle = (_, __) => gate.future;
    final pending =
        ReportCommentsService(backend: b).add('report', 'Hello', 'id');
    b.uid = 'other';
    gate.complete(comment(id: 'id', body: 'Hello'));
    await expectLater(
        pending,
        throwsA(isA<CommentsException>()
            .having((e) => e.forbidden, 'forbidden', true)));
  });
  test('malformed and mismatched receipts are uncertain writes', () async {
    final b = CommentsBackend();
    for (final raw in [
      null,
      {},
      comment(id: 'wrong', body: 'Hello'),
      {...comment(id: 'id', body: 'Hello'), 'isMine': false}
    ]) {
      b.handle = (_, __) async => raw;
      await expectLater(
          ReportCommentsService(backend: b).add('report', 'Hello', 'id'),
          throwsA(isA<CommentsException>()
              .having((e) => e.uncertain, 'uncertain', true)));
    }
  });
  test('retry after a lost response preserves both request UUID and draft',
      () async {
    final b = CommentsBackend();
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    c.updateDraft('  The road is blocked.  ');
    b.handle = (_, __) async => throw TimeoutException('lost response');
    await c.post();
    final first = b.calls.last.$2;
    expect(c.uncertain, true);
    c.updateDraft('Attempt to change an uncertain payload');
    expect(c.draft, '  The road is blocked.  ');
    b.handle =
        (_, p) async => comment(id: p['p_request_id'], body: p['p_body']);
    await c.post();
    expect(b.calls.last.$2, first);
    expect(c.comments.single.body, 'The road is blocked.');
    expect(c.draft, isEmpty);
    expect(c.uncertain, false);
    c.dispose();
  });
  test('acknowledged post is retained when a later refresh fails', () async {
    final b = CommentsBackend();
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    c.updateDraft('Confirmed repair details');
    await c.post();
    final id = c.comments.single.id;
    b.handle = (_, __) async => throw TimeoutException('offline');
    await c.load();
    expect(c.comments.single.id, id);
    expect(c.draft, isEmpty);
    expect(c.error, isNotNull);
    c.dispose();
  });
  test('a panel from an old account cannot post under the new account',
      () async {
    final b = CommentsBackend();
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    c.updateDraft('Old account draft');
    b.uid = 'other';
    await c.post();
    expect(b.calls.length, 1);
    expect(c.blocked, true);
    expect(c.comments, isEmpty);
    c.dispose();
  });
  test('older pages merge without duplicates and survive loading errors',
      () async {
    final b = CommentsBackend();
    var page = 0;
    b.handle = (_, __) async => {
          'comments': [comment(id: page++ == 0 ? 'new' : 'old')],
          'hasMore': true
        };
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    await c.load(older: true);
    await c.load(older: true);
    expect(c.comments.map((e) => e.id), ['new', 'old']);
    c.dispose();
  });
  test('own removal is acknowledged; another author cannot be removed by UI',
      () async {
    final b = CommentsBackend();
    b.handle = (name, p) async => name == 'list_report_comments'
        ? {
            'comments': [
              comment(),
              {...comment(id: 'other'), 'isMine': false}
            ],
            'hasMore': false
          }
        : {'id': p['p_comment_id'], 'deleted': true};
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    await c.remove(c.comments.last);
    expect(b.calls.length, 1);
    await c.remove(c.comments.first);
    expect(c.comments.single.id, 'other');
    c.dispose();
  });
  test('unavailable reports block further posting', () async {
    final b = CommentsBackend()
      ..handle = (_, __) async =>
          throw const PostgrestException(message: 'unavailable', code: '42501');
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    c.updateDraft('Trying a removed report');
    await c.post();
    expect(c.blocked, true);
    expect(b.calls.length, 1);
    c.dispose();
  });
  test('preview read, add and removal never call hosted services', () async {
    AppSession.instance.enterPreview();
    final b = CommentsBackend();
    final s = ReportCommentsService(backend: b);
    await s.list('preview-test');
    final item =
        await s.add('preview-test', 'Preview only comment', 'preview-id');
    await s.remove('preview-test', item.id);
    expect((await s.list('preview-test')).comments, isEmpty);
    expect(b.calls, isEmpty);
    AppSession.instance.leavePreview();
  });
  test('an uncertain removal retries the same identity and blocks new posts',
      () async {
    final b = CommentsBackend();
    b.handle = (_, __) async => {
          'comments': [comment()],
          'hasMore': false
        };
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    final item = c.comments.single;
    b.handle = (_, __) async => throw TimeoutException('lost delete response');
    await c.remove(item);
    expect(c.pendingRemoval, item.id);
    expect(c.canPost, false);
    expect(c.canRefresh, false);
    final first = b.calls.last.$2;
    b.handle = (_, p) async => {'id': p['p_comment_id'], 'deleted': true};
    await c.remove(item);
    expect(b.calls.last.$2, first);
    expect(c.pendingRemoval, isNull);
    expect(c.comments, isEmpty);
    c.dispose();
  });
  test('terminal removed replay unlocks the draft with a new request identity',
      () async {
    final b = CommentsBackend();
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    c.updateDraft('A useful detail');
    b.handle = (_, __) async => throw TimeoutException('lost');
    await c.post();
    final first = b.calls.last.$2['p_request_id'];
    b.handle = (_, __) async =>
        throw const PostgrestException(message: 'removed', code: 'PT409');
    await c.post();
    expect(c.uncertain, false);
    expect(c.canEdit, true);
    b.handle =
        (_, p) async => comment(id: p['p_request_id'], body: p['p_body']);
    await c.post();
    expect(b.calls.last.$2['p_request_id'], isNot(first));
    c.dispose();
  });
  test('read responses from another report or an oversized page are rejected',
      () async {
    final b = CommentsBackend();
    final s = ReportCommentsService(backend: b);
    for (final raw in [
      {
        'comments': [
          {...comment(), 'reportId': 'other'}
        ],
        'hasMore': false
      },
      {'comments': List.filled(21, comment()), 'hasMore': true},
      {'comments': [], 'hasMore': true},
    ]) {
      b.handle = (_, __) async => raw;
      await expectLater(s.list('report'), throwsA(isA<CommentsException>()));
    }
  });
  test('a page from a superseded session is discarded', () async {
    final b = CommentsBackend();
    final gate = Completer<dynamic>();
    b.handle = (_, __) => gate.future;
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    final pending = c.load();
    b.uid = 'different';
    gate.complete({
      'comments': [comment()],
      'hasMore': false
    });
    await pending;
    expect(c.comments, isEmpty);
    expect(c.blocked, true);
    c.dispose();
  });
  test('refresh preserves a draft and cannot overlap an older-page request',
      () async {
    final b = CommentsBackend();
    b.handle = (_, __) async => {
          'comments': [comment()],
          'hasMore': true
        };
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    await c.load();
    c.updateDraft('Unpublished draft');
    final gate = Completer<dynamic>();
    b.handle = (_, __) => gate.future;
    final older = c.load(older: true);
    await c.load();
    expect(b.calls.length, 2);
    gate.complete({
      'comments': [comment(id: 'older')],
      'hasMore': false
    });
    await older;
    expect(c.draft, 'Unpublished draft');
    expect(c.comments.length, 2);
    c.dispose();
  });
  test('disposing a panel while loading suppresses stale notifications',
      () async {
    final b = CommentsBackend();
    final gate = Completer<dynamic>();
    b.handle = (_, __) => gate.future;
    final c = ReportCommentsController(
        reportId: 'report', service: ReportCommentsService(backend: b));
    final pending = c.load();
    c.dispose();
    gate.complete({
      'comments': [comment()],
      'hasMore': false
    });
    await pending;
    expect(c.comments, isEmpty);
  });
}
