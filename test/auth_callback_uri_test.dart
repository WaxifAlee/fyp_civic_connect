import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/services/auth_callback_uri.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';

void main() {
  test('successful callback is removed before a browser reload can replay it',
      () async {
    var location =
        Uri.parse('https://civic.example/?code=one-time&view=reports#/welcome');
    var exchanges = 0;
    Future<void> initialize() async {
      if (SupabaseService.isAuthCallback(location,
          isWeb: true, webOrigin: 'https://civic.example')) {
        await consumeBrowserAuthCallback(location, () async {
          exchanges++;
        }, (uri) => location = uri);
      }
    }

    await initialize();
    await initialize(); // A new process sees the replaced browser location.
    expect(exchanges, 1);
    expect(location.queryParameters, {'view': 'reports'});
    expect(location.fragment, '/welcome');
  });

  test('expired links and implicit token fragments are also removed', () async {
    var location = Uri.parse(
        'https://civic.example/#access_token=secret&refresh_token=secret&type=recovery');
    await expectLater(
        consumeBrowserAuthCallback(location,
            () async => throw StateError('expired'), (uri) => location = uri),
        throwsStateError);
    expect(location.fragment, isEmpty);
    expect(
        SupabaseService.isAuthCallback(location,
            isWeb: true, webOrigin: 'https://civic.example'),
        isFalse);
  });
}
