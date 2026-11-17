import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/models/report.dart';

void main() {
  test('legacy aliases and DateTime round-trip without backend types', () {
    final date = DateTime.utc(2026, 11, 17);
    final report = Report.fromMap({
      'mediaRefrence': ['photo'],
      'reportedBy': 'owner',
      'profilePicture': 'avatar',
      'date': date,
      'upvotes': -4,
    });
    expect(report.date, date);
    expect(report.mediaRefrence, ['photo']);
    expect(report.reportedBy, 'owner');
    expect(report.profilePicture, 'avatar');
    expect(Report.fromMap(report.toMap()).date, date);
    expect(report.upvotes, 0);
  });

  test('malformed dates and optional lists remain readable', () {
    final report = Report.fromMap({
      'timestamp': 15,
      'images': false,
      'upvotedBy': [null, '', 1],
    });
    expect(report.date, isNull);
    expect(report.mediaRefrence, isEmpty);
    expect(report.upvotedBy, isEmpty);
  });

  test('incomplete legacy records remain readable', () {
    final report = Report.fromMap({'title': 'Broken streetlight'});
    expect(report.title, 'Broken streetlight');
    expect(report.mediaRefrence, isEmpty);
    expect(report.upvotes, 0);
    expect(report.date, isNull);
  });

  test('accepts RPC field aliases and malformed optional data', () {
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
