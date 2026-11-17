import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/reports/application/reports_controller.dart';
import 'package:fyp_civic_connect/features/reports/data/preview_reports.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:fyp_civic_connect/models/report.dart';

void main() {
  tearDown(() => AppSession.instance.leavePreview());
  test('manual coordinates and GPS use the same geographic boundary', () {
    expect(FatehJangArea.validate(33.55, 72.63), isNull);
    expect(FatehJangArea.contains(const LatLng(33.55, 72.63)), isTrue);
    expect(FatehJangArea.contains(const LatLng(33.6844, 72.9784)), isFalse);
    expect(FatehJangArea.validate(200, 72.63), isNotNull);
    expect(FatehJangArea.validate(33.55, double.nan), isNotNull);
    expect(FatehJangArea.validate(null, 72.63), isNotNull);
    expect(FatehJangArea.contains(FatehJangArea.boundary.first), isTrue);
  });

  test('unsupported or empty photos fail before upload', () async {
    for (final data in [
      Uint8List(0),
      Uint8List.fromList('not an image'.codeUnits),
    ]) {
      await expectLater(
        ReportSubmissionService.readPhoto(XFile.fromData(data)),
        throwsA(isA<ReportSubmissionException>()),
      );
    }
  });

  test('oversized photos are rejected before reading upload bytes', () async {
    final file = XFile.fromData(
      Uint8List(ReportSubmissionService.maxImageBytes + 1),
    );
    await expectLater(
      ReportSubmissionService.readPhoto(file),
      throwsA(isA<ReportSubmissionException>()),
    );
  });

  test('preview submission never accesses the backend SDK', () async {
    AppSession.instance.enterPreview();
    await expectLater(
      ReportSubmissionService().submit(
        title: 'Streetlight repair',
        description: 'The light is not working near the market.',
        category: 'Electricity & Gas Department',
        location: FatehJangArea.center,
        images: [],
      ),
      throwsA(isA<ReportSubmissionException>()),
    );
  });

  test(
    'preview supports and un-supports issues without initialized backends',
    () async {
      AppSession.instance.enterPreview();
      final controller = ReportsController();
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.error, isNull);
      final report = controller.reports.first;
      final previous = report.upvotes;
      expect(await controller.toggleUpvote(report), isTrue);
      expect(report.upvotes, previous! + 1);
      expect(report.upvotedBy, contains(PreviewReports.citizenId));
      expect(await controller.toggleUpvote(report), isTrue);
      expect(report.upvotes, previous);
      expect(report.upvotedBy, isNot(contains(PreviewReports.citizenId)));
    },
  );

  test('a citizen cannot delete somebody else’s report', () async {
    AppSession.instance.enterPreview();
    final controller = ReportsController(mine: true);
    addTearDown(controller.dispose);
    await controller.load();
    expect(
      controller.reports.every((r) => r.reportedBy == PreviewReports.citizenId),
      isTrue,
    );
    expect(
      await controller.delete(Report(id: 'other', reportedBy: 'someone-else')),
      isFalse,
    );
  });
}
