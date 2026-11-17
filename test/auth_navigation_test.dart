import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/app/civic_connect_app.dart';
import 'package:fyp_civic_connect/features/auth/recovery_screen.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.leavePreview();
    SupabaseService.navigation.value = null;
    SupabaseService.recoveryActive = false;
  });

  testWidgets('a recovery event queued before app mount opens recovery',
      (tester) async {
    SupabaseService.navigation.value = AuthNavigation.recovery;
    await tester.pumpWidget(const CivicConnectApp(initialRoute: '/welcome'));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryScreen), findsOneWidget);
    expect(find.textContaining('session is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recovery event opens recovery in an already running app',
      (tester) async {
    await tester.pumpWidget(const CivicConnectApp(initialRoute: '/welcome'));
    await tester.pumpAndSettle();
    SupabaseService.navigation.value = AuthNavigation.recovery;
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a background sign-out does not replace an active demo',
      (tester) async {
    AppSession.instance.enterPreview();
    await tester.pumpWidget(const CivicConnectApp(initialRoute: '/dashboard'));
    await tester.pumpAndSettle();
    SupabaseService.navigation.value = AuthNavigation.signedOut;
    await tester.pumpAndSettle();
    expect(AppSession.instance.isPreview, isTrue);
    expect(find.text('Your recent reports'), findsOneWidget);
  });
}
