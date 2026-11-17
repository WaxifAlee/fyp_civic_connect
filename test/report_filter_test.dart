import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/features/reports/domain/report_filters.dart';

void main() {
  final reports = [
    Report(
        id: '1',
        title: 'Streetlight',
        category: 'Electricity & Gas Department',
        status: 'done',
        reportCode: 'EG00001',
        upvotes: 2),
    Report(
        id: '2',
        title: 'Road repair',
        category: 'Public Works Department (PWD)',
        status: 'in_progress',
        reportCode: 'PW00002',
        upvotes: 8),
    Report(
        id: '3',
        title: 'Road drain',
        category: 'Municipal Corportaion',
        status: 'pending',
        reportCode: 'MC00003',
        upvotes: 3),
  ];
  test('status aliases represent the same progress state', () {
    expect(ReportStatus.parse('done'), ReportStatus.resolved);
    expect(ReportStatus.parse('In_Progress'), ReportStatus.inProgress);
    expect(ReportStatus.parse('unrecognized'), ReportStatus.unknown);
  });
  test('query category and status compose without overwriting each other', () {
    final filter = ReportFilter(
        query: 'road',
        category: 'Municipal Corportaion',
        status: ReportStatus.pending);
    expect(filter.apply(reports).map((e) => e.id), ['3']);
  });
  test('search includes report code and sorting does not mutate source', () {
    expect(ReportFilter(query: ' eg00001 ').apply(reports).single.id, '1');
    expect(ReportFilter(sort: ReportSort.mostSupported).apply(reports).first.id,
        '2');
    expect(reports.first.id, '1');
  });
}
