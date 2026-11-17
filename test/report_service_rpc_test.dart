import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/reports/application/reports_controller.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/services/report_service.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';

class RpcBackend extends ReportBackend {
  String? uid = owner;
  final calls = <(String, Map<String, dynamic>)>[];
  final removed = <String>[];
  final urls = <String>[];
  bool failRemove = false;
  Future<dynamic> Function(String, Map<String, dynamic>)? respond;
  List<Map<String, dynamic>> cleanup = [];

  @override
  bool get isConfigured => true;
  @override
  String? get verifiedUserId => uid;
  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    calls.add((name, Map.of(params)));
    if (name == 'list_report_cleanup') return cleanup;
    if (name == 'complete_report_cleanup') return null;
    return respond!(name, params);
  }

  @override
  Future<void> remove(List<String> paths) async {
    if (failRemove) throw StateError('storage unavailable');
    removed.addAll(paths);
  }

  @override
  String publicUrl(String bucket, String path) {
    urls.add('$bucket/$path');
    return 'https://example.test/$bucket/$path';
  }
}

Map<String, dynamic> row(int index) => {
      'id': '$index',
      'reporterId': owner,
      'title': 'Issue $index',
      'category': index == 200 ? 'Police Department' : 'Municipal Corportaion',
      'status': 'pending',
      'timestamp': '2026-11-17T10:00:00Z',
      'upvotes': index,
      'upvotedBy': [owner, other],
      'images': [
        '$owner/photo.jpg',
        'https://evil.test/image.jpg',
        '../other.png'
      ],
      'avatar': '$other/avatar.webp',
    };

void main() {
  setUp(() => AppSession.instance.leavePreview());

  test(
      'bounded pagination fetches the entire feed before filtering and sorting',
      () async {
    final backend = RpcBackend();
    backend.respond = (name, params) async {
      expect(name, 'list_reports');
      expect(params['p_limit'], 200);
      expect(params['p_mine'], false);
      final offset = params['p_offset'] as int;
      return List.generate(offset == 0 ? 200 : 1, (i) => row(offset + i));
    };
    final reports = await ReportService(backend: backend).fetchAllReports(
        category: 'Police Department',
        status: 'pending',
        sortByPopularity: true);
    expect(backend.calls.map((call) => call.$2['p_offset']), [0, 200]);
    expect(reports.single.id, '200');
    expect(reports.single.upvotedBy, [owner]);
    expect(reports.single.mediaRefrence,
        ['https://example.test/reports-images/$owner/photo.jpg']);
    expect(reports.single.profilePicture,
        'https://example.test/profile-pictures/$other/avatar.webp');
    expect(backend.urls.any((url) => url.contains('evil')), false);
  });

  test('mine requests use the server scope and exclude unexpected owners',
      () async {
    final backend = RpcBackend();
    backend.respond = (_, params) async {
      expect(params['p_mine'], true);
      return [
        row(0),
        {...row(1), 'reporterId': other}
      ];
    };
    final reports =
        await ReportService(backend: backend).fetchReportsByCurrentUser();
    expect(reports.map((r) => r.reportedBy), [owner]);
  });

  test('delete cleans only authoritative own paths, ignoring caller URLs',
      () async {
    final backend = RpcBackend();
    backend.respond = (_, __) async => [
          '$owner/server.jpg',
          '$other/other.jpg',
          'https://evil.test/photo.jpg'
        ];
    await ReportService(backend: backend)
        .deleteReport('report-id', ['$owner/caller.jpg']);
    expect(backend.calls.first.$1, 'delete_report');
    expect(backend.calls.first.$2, {'p_report_id': 'report-id'});
    expect(backend.calls.last.$1, 'complete_report_cleanup');
    expect(backend.calls.last.$2, {'p_report_id': 'report-id'});
    expect(backend.removed, ['$owner/server.jpg']);
  });

  test('failed database delete never cleans storage', () async {
    final backend = RpcBackend();
    backend.respond = (_, __) async => throw StateError('not owner');
    await expectLater(
        ReportService(backend: backend)
            .deleteReport('id', ['$owner/photo.jpg']),
        throwsStateError);
    expect(backend.removed, isEmpty);
  });

  test('support exposes only the current user identity and authoritative count',
      () async {
    final backend = RpcBackend();
    backend.respond = (_, __) async => {
          'count': 73,
          'voters': [owner, other]
        };
    final result = await ReportService(backend: backend).toggleUpvote('id');
    expect(result.count, 73);
    expect(result.voters, [owner]);
  });

  test('changed session discards response and prevents next paginated request',
      () async {
    final backend = RpcBackend();
    backend.respond = (_, __) async {
      backend.uid = other;
      return List.generate(200, row);
    };
    await expectLater(
        ReportService(backend: backend).fetchAllReports(), throwsStateError);
    expect(backend.calls, hasLength(1));
  });

  test('changed session after delete prevents photo cleanup', () async {
    final backend = RpcBackend();
    backend.respond = (_, __) async {
      backend.uid = other;
      return ['$owner/server.jpg'];
    };
    await expectLater(ReportService(backend: backend).deleteReport('id', []),
        throwsStateError);
    expect(backend.removed, isEmpty);
  });

  test('own report fetch retries persisted cleanup then completes the manifest',
      () async {
    final backend = RpcBackend()
      ..cleanup = [
        {
          'reportId': 'deleted-report',
          'paths': ['$owner/old.jpg']
        }
      ];
    backend.respond = (_, __) async => [];
    await ReportService(backend: backend).fetchReportsByCurrentUser();
    expect(backend.removed, ['$owner/old.jpg']);
    expect(backend.calls.map((call) => call.$1),
        ['list_reports', 'list_report_cleanup', 'complete_report_cleanup']);
    expect(backend.calls.last.$2, {'p_report_id': 'deleted-report'});
  });

  test(
      'failed storage cleanup leaves its manifest and still returns own reports',
      () async {
    final backend = RpcBackend()
      ..failRemove = true
      ..cleanup = [
        {
          'reportId': 'deleted-report',
          'paths': ['$owner/old.jpg']
        }
      ];
    backend.respond = (_, __) async => [row(0)];
    final reports =
        await ReportService(backend: backend).fetchReportsByCurrentUser();
    expect(reports, hasLength(1));
    expect(backend.calls.map((call) => call.$1),
        ['list_reports', 'list_report_cleanup']);
  });

  test('delete storage failure remains a successful idempotent row deletion',
      () async {
    final backend = RpcBackend()..failRemove = true;
    backend.respond = (_, __) async => ['$owner/old.jpg'];
    final service = ReportService(backend: backend);
    await service.deleteReport('same-id', []);
    backend.failRemove = false;
    await service.deleteReport('same-id', []);
    expect(
        backend.calls
            .where((call) => call.$1 == 'delete_report')
            .map((call) => call.$2['p_report_id']),
        ['same-id', 'same-id']);
    expect(backend.removed, ['$owner/old.jpg']);
    expect(backend.calls.last.$1, 'complete_report_cleanup');
  });

  test(
      'lost delete response is retried with the same report ID and server paths',
      () async {
    final backend = RpcBackend();
    var deleted = false;
    backend.respond = (_, __) async {
      if (!deleted) {
        deleted = true;
        throw StateError('delete committed but response lost');
      }
      return ['$owner/saved.jpg'];
    };
    final service = ReportService(backend: backend);
    await expectLater(service.deleteReport('same-id', ['$owner/untrusted.jpg']),
        throwsStateError);
    expect(backend.removed, isEmpty);
    await service.deleteReport('same-id', ['$owner/untrusted.jpg']);
    expect(backend.removed, ['$owner/saved.jpg']);
    expect(
        backend.calls
            .where((call) => call.$1 == 'delete_report')
            .map((call) => call.$2['p_report_id']),
        ['same-id', 'same-id']);
    expect(backend.calls.last.$1, 'complete_report_cleanup');
  });

  test('preview blocks all service calls before accessing the SDK', () async {
    AppSession.instance.enterPreview();
    final service = ReportService();
    await expectLater(service.fetchAllReports(), throwsStateError);
    await expectLater(service.toggleUpvote('id'), throwsStateError);
    await expectLater(service.deleteReport('id', []), throwsStateError);
  });

  test(
      'controller accepts own-only support and ignores a stale session response',
      () async {
    final backend = RpcBackend();
    final gate = Completer<dynamic>();
    backend.respond = (_, __) => gate.future;
    final controller = ReportsController(
        service: ReportService(backend: backend), userId: () => backend.uid);
    addTearDown(controller.dispose);
    final report = Report(id: 'id', upvotes: 2);
    final vote = controller.toggleUpvote(report);
    backend.uid = other;
    gate.complete({
      'count': 3,
      'voters': [owner]
    });
    expect(await vote, false);
    expect(report.upvotes, 2);
  });
}
