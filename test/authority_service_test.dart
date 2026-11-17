import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/authority/application/authority_controller.dart';
import 'package:fyp_civic_connect/features/authority/data/authority_service.dart';
import 'package:fyp_civic_connect/features/authority/domain/authority_models.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthorityBackend extends ReportBackend {
  String? uid = 'test-staff';
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
    if (name == 'get_authority_access') {
      return {'role': 'admin', 'department': null};
    }
    return {
      'reports': [],
      'total': 0,
      'counts': {
        'total': 0,
        'pending': 0,
        'inprogress': 0,
        'resolved': 0,
        'rejected': 0
      }
    };
  }
}

void main() {
  setUp(() => AppSession.instance.leavePreview());
  for (final criterion in ['query', 'status', 'category', 'sort', 'page']) {
    test(
        'failed $criterion change never retains a queue from different criteria',
        () async {
      final backend = AuthorityBackend();
      final controller =
          AuthorityController(service: AuthorityService(backend: backend));
      addTearDown(controller.dispose);
      await controller.load();
      switch (criterion) {
        case 'query':
          controller.query = 'school';
        case 'status':
          controller.status = 'resolved';
        case 'category':
          controller.category = 'Police Department';
        case 'sort':
          controller.sort = 'newest';
        case 'page':
          controller.pageIndex = 1;
      }
      backend.handle = (name, _) async {
        if (name == 'get_authority_access') {
          return {'role': 'admin', 'department': null};
        }
        throw const AuthorityException('Offline');
      };
      await controller.load();
      await controller.load(retainPage: true);
      expect(controller.retainingPage, isFalse);
    });
  }

  test('membership changes notify the UI before the new queue finishes loading',
      () async {
    final backend = AuthorityBackend();
    final controller =
        AuthorityController(service: AuthorityService(backend: backend));
    addTearDown(controller.dispose);
    await controller.load();
    var clearedScopeRendered = false;
    controller.addListener(() {
      if (controller.access?.role == 'department' && controller.page == null) {
        clearedScopeRendered = true;
      }
    });
    final queue = Completer<dynamic>();
    backend.handle = (name, _) async {
      if (name == 'get_authority_access') {
        return {'role': 'department', 'department': 'Police Department'};
      }
      return queue.future;
    };
    final refresh = controller.load(retainPage: true);
    await Future<void>.delayed(Duration.zero);
    try {
      expect(clearedScopeRendered, isTrue);
    } finally {
      queue.complete({
        'reports': [],
        'total': 0,
        'counts': {
          'total': 0,
          'pending': 0,
          'inprogress': 0,
          'resolved': 0,
          'rejected': 0
        }
      });
      await refresh;
    }
  });
  test(
      'staff access validates role and department instead of trusting metadata',
      () async {
    final backend = AuthorityBackend();
    final service = AuthorityService(backend: backend);
    expect((await service.access())!.isAdmin, isTrue);
    backend.handle =
        (_, __) async => {'role': 'admin', 'department': 'Police Department'};
    await expectLater(service.access(), throwsA(isA<AuthorityException>()));
    backend.handle = (_, __) async => null;
    expect(await service.access(), isNull);
  });
  test('queue sends bounded server filters and offset', () async {
    final backend = AuthorityBackend();
    final service = AuthorityService(backend: backend);
    await service.queue(
        query: 'MC001',
        status: 'pending',
        category: 'Municipal Corportaion',
        sort: 'newest',
        page: 2);
    expect(backend.calls.single.$2, {
      'p_query': 'MC001',
      'p_status': 'pending',
      'p_category': 'Municipal Corportaion',
      'p_sort': 'newest',
      'p_limit': 20,
      'p_offset': 40
    });
  });
  test('session change discards a completed authority request', () async {
    final backend = AuthorityBackend();
    final gate = Completer<dynamic>();
    backend.handle = (_, __) => gate.future;
    final pending = AuthorityService(backend: backend).access();
    backend.uid = 'another-user';
    gate.complete({'role': 'admin', 'department': null});
    await expectLater(pending, throwsA(isA<AuthorityException>()));
  });
  test('stale versions produce an actionable conflict', () async {
    final backend = AuthorityBackend();
    backend.handle = (_, __) async =>
        throw const PostgrestException(message: 'stale', code: 'PT409');
    await expectLater(
        AuthorityService(backend: backend).publish(
            id: 'report',
            version: 2,
            status: 'resolved',
            note: 'The repair is complete.',
            requestId: 'request'),
        throwsA(isA<AuthorityException>()
            .having((e) => e.conflict, 'conflict', isTrue)));
  });
  test('a superseded search cannot replace the current queue', () async {
    final backend = AuthorityBackend();
    final old = Completer<dynamic>();
    final fresh = Completer<dynamic>();
    backend.handle = (name, params) async {
      if (name == 'get_authority_access') {
        return {'role': 'admin', 'department': null};
      }
      return params['p_query'] == 'old' ? old.future : fresh.future;
    };
    final controller =
        AuthorityController(service: AuthorityService(backend: backend));
    final first = controller.load(query: 'old');
    await Future<void>.delayed(Duration.zero);
    final second = controller.load(query: 'fresh');
    fresh.complete({
      'reports': [],
      'total': 7,
      'counts': {
        'total': 7,
        'pending': 7,
        'inprogress': 0,
        'resolved': 0,
        'rejected': 0
      }
    });
    await second;
    old.complete({
      'reports': [],
      'total': 1,
      'counts': {
        'total': 1,
        'pending': 1,
        'inprogress': 0,
        'resolved': 0,
        'rejected': 0
      }
    });
    await first;
    expect(controller.page!.total, 7);
    expect(controller.query, 'fresh');
    controller.dispose();
  });
  test('nonmember never requests a queue', () async {
    final backend = AuthorityBackend()..handle = (_, __) async => null;
    final controller =
        AuthorityController(service: AuthorityService(backend: backend));
    await controller.load();
    expect(controller.denied, isTrue);
    expect(backend.calls.map((e) => e.$1), ['get_authority_access']);
    controller.dispose();
  });
  test('preview authority mutations stay in memory and expose progress',
      () async {
    AppSession.instance.enterPreview();
    final backend = AuthorityBackend()
      ..handle = (_, __) async => throw StateError('remote call');
    final service = AuthorityService(backend: backend);
    final page = await service.queue(status: 'pending');
    final report = page.reports.first;
    await service.publish(
        id: report.report.id!,
        version: report.version,
        status: 'inprogress',
        note: 'A crew has been scheduled.',
        requestId: 'demo-test-request');
    final detail = await service.detail(report.report.id!);
    expect(detail.item.report.status, 'inprogress');
    expect(detail.history.first.note, 'A crew has been scheduled.');
    expect(backend.calls, isEmpty);
    AppSession.instance.leavePreview();
  });
  test('malformed mutation receipts preserve an uncertain outcome', () async {
    final backend = AuthorityBackend()
      ..handle = (_, __) async => {'id': 'report', 'status': 'resolved'};
    await expectLater(
        AuthorityService(backend: backend).publish(
            id: 'report',
            version: 0,
            status: 'resolved',
            note: 'The repair is complete.',
            requestId: 'request'),
        throwsA(isA<AuthorityException>()
            .having((e) => e.uncertain, 'uncertain', isTrue)));
  });
  test('transition choices reflect the server workflow', () {
    expect(
        authorityTransitions('pending'), ['pending', 'inprogress', 'rejected']);
    expect(authorityTransitions('resolved'), ['resolved', 'inprogress']);
    expect(authorityTransitions('forged'), isEmpty);
  });
}
