import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/reports/application/reports_controller.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/services/report_service.dart';

class RefreshService extends ReportService {
  final requests = <Completer<List<Report>>>[];
  @override
  Future<List<Report>> fetchAllReports(
      {String? category, String? status, bool sortByPopularity = false}) {
    final request = Completer<List<Report>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> deleteReport(String id, List<String> mediaReferences) async {}

  @override
  Future<ReportVote> toggleUpvote(String id) async =>
      const ReportVote(count: 3, voters: ['citizen']);
}

void main() {
  late RefreshService service;
  late ReportsController controller;
  setUp(() {
    AppSession.instance.leavePreview();
    service = RefreshService();
    controller = ReportsController(service: service, userId: () => 'citizen');
  });
  tearDown(() => controller.dispose());

  test(
      'refresh failure retains the last successful reports and shows retry feedback',
      () async {
    final initial = controller.load();
    service.requests.last.complete([Report(id: 'one')]);
    await initial;
    final refresh = controller.load();
    expect(controller.reports.single.id, 'one');
    expect(controller.hasLoaded, isTrue);
    service.requests.last.completeError(Exception('offline'));
    await refresh;
    expect(controller.reports.single.id, 'one');
    expect(controller.error, contains('refresh'));
    expect(controller.loading, isFalse);
  });

  test('overlapping refreshes share one request and remain busy until settled',
      () async {
    final first = controller.load();
    final second = controller.load();
    expect(service.requests, hasLength(1));
    service.requests.single.complete([Report(id: 'one')]);
    await Future.wait([first, second]);
    expect(controller.loading, isFalse);
    expect(controller.reports.single.id, 'one');
  });

  test('a delayed refresh cannot restore a deleted report', () async {
    final initial = controller.load();
    service.requests.last.complete([Report(id: 'one', reportedBy: 'citizen')]);
    await initial;
    final refresh = controller.load();
    expect(await controller.delete(controller.reports.single), isTrue);
    service.requests.last.complete([Report(id: 'one', reportedBy: 'citizen')]);
    await refresh;
    expect(controller.reports, isEmpty);
  });

  test('a delayed refresh cannot overwrite confirmed support', () async {
    final initial = controller.load();
    service.requests.last.complete([Report(id: 'one', upvotes: 0)]);
    await initial;
    final refresh = controller.load();
    expect(await controller.toggleUpvote(controller.reports.single), isTrue);
    service.requests.last.complete([Report(id: 'one', upvotes: 0)]);
    await refresh;
    expect(controller.reports.single.upvotes, 3);
  });

  test('previous account reports are cleared before loading another account',
      () async {
    controller.dispose();
    var uid = 'citizen';
    controller = ReportsController(service: service, userId: () => uid);
    final initial = controller.load();
    service.requests.last.complete([Report(id: 'old-account')]);
    await initial;
    uid = 'another-citizen';
    final refresh = controller.load();
    expect(controller.reports, isEmpty);
    expect(controller.hasLoaded, isFalse);
    service.requests.last.complete([]);
    await refresh;
  });
}
