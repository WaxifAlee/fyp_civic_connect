import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/services/storage_paths.dart';

void main() {
  test('cleanup ignores legacy, malformed, and unrelated image references', () {
    expect(
        reportImageStoragePaths([
          'public/photo.jpg',
          'not-a-url',
          'https://other.example/storage/v1/object/public/reports-images/public/other.jpg',
          'https://civic.example/storage/v1/object/public/other-bucket/public/other.jpg',
          'https://civic.example/storage/v1/object/public/reports-images/public/photo.jpg',
        ], 'https://civic.example'),
        ['public/photo.jpg']);
    expect(reportImageStoragePaths(['public/photo.jpg'], ''), isEmpty);
  });
}
