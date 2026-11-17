import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:fyp_civic_connect/features/reports/application/reports_controller.dart';

class CommittedVoteService extends ReportService {
  @override
  Future<ReportVote> toggleUpvote(String id) async =>
      const ReportVote(count: 0, voters: []);
}

void main() {
  test('support follows the server transaction when another session changed it',
      () async {
    AppSession.instance.leavePreview();
    final controller = ReportsController(
        service: CommittedVoteService(), userId: () => 'citizen');
    addTearDown(controller.dispose);
    final staleReport = Report(id: 'report', upvotes: 0, upvotedBy: []);
    // Another session already supported it. The next toggle removes that support.
    expect(await controller.toggleUpvote(staleReport), isTrue);
    expect(staleReport.upvotes, 0);
    expect(staleReport.upvotedBy, isEmpty);
  });
}
