import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/account/profile.dart';
import 'package:fyp_civic_connect/models/citizen_user.dart';
import 'package:fyp_civic_connect/services/citizen_account_service.dart';
import 'package:fyp_civic_connect/services/user_service.dart';

class InterruptedAccount extends CitizenAccountService {
  var name = 'Original Citizen';
  var loads = 0;
  @override
  String get userId => '11111111-1111-4111-8111-111111111111';
  @override
  Future<CitizenUser> load() async {
    loads++;
    return CitizenUser(
        uid: userId,
        fullName: name,
        phone: '+923001234567',
        location: 'Fateh Jang',
        email: 'citizen@example.com',
        displayPicture: '',
        cnic: null,
        gender: null,
        joinDate: null);
  }

  @override
  Future<void> save(
      {required String fullName,
      required String phone,
      required String location}) async {
    name = fullName; // The server committed; only the response was lost.
    throw StateError('response lost');
  }
}

void main() {
  testWidgets(
      'an uncertain account write blocks stale edits until fresh data loads',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.leavePreview();
    final account = InterruptedAccount();
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: Profile(account: account)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit details'));
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Saved Citizen');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Account unavailable'), findsOneWidget);
    expect(find.text('Edit details'), findsNothing);
    expect(find.text('Change photo'), findsNothing);
    expect(globalCitizenUser, isNull);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(account.loads, 2);
    expect(find.text('Saved Citizen'), findsWidgets);
    expect(find.text('Account unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
