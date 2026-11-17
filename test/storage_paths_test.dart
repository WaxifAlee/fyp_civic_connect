import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/services/storage_paths.dart';

void main() {
  test('avatar cleanup is restricted to the deployment and account', () {
    const owner = '11111111-1111-4111-8111-111111111111';
    const path = '$owner/22222222-2222-4222-8222-222222222222.png';
    const url =
        'https://civic.example/storage/v1/object/public/profile-pictures/$path';
    expect(ownedAvatarStoragePath(url, 'https://civic.example', owner), path);
    expect(ownedAvatarStoragePath(url, 'https://other.example', owner), isNull);
    expect(
        ownedAvatarStoragePath(url, 'https://civic.example', 'another-owner'),
        isNull);
    expect(
        ownedAvatarStoragePath(
            'public/old.jpg', 'https://civic.example', owner),
        isNull);
  });
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
