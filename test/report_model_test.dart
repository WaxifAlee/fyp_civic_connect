import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/models/report.dart';

void main() {
  test('incomplete legacy records remain readable', () {
    final report = Report.fromMap({'title': 'Broken streetlight'});
    expect(report.title, 'Broken streetlight');
    expect(report.mediaRefrence, isEmpty);
    expect(report.upvotes, 0);
    expect(report.date, isNull);
  });

  test('accepts Firestore field aliases and malformed optional data', () {
    final report = Report.fromMap({
      'images': ['https://example.org/photo.jpg', null],
      'reporterId': 'citizen-1',
      'avatar': 'https://example.org/avatar.jpg',
      'timestamp': '2026-11-17T10:00:00Z',
      'upvotes': 4.0,
      'upvotedBy': ['citizen-2'],
    });
    expect(report.reportedBy, 'citizen-1');
    expect(report.mediaRefrence, ['https://example.org/photo.jpg']);
    expect(report.date?.year, 2026);
    expect(report.upvotes, 4);
  });
}
