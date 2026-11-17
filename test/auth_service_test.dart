// The application already receives HTTP through the locked Supabase dependency.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/auth/auth_flow.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const uid = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> userJson({String id = uid, bool verified = true}) => {
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': {
        'provider': 'email',
        'providers': ['email']
      },
      'user_metadata': <String, dynamic>{},
      'email': 'citizen@example.com',
      'created_at': '2026-11-17T00:00:00Z',
      if (verified) 'email_confirmed_at': '2026-11-17T00:00:00Z',
      'identities': <dynamic>[],
    };

Map<String, dynamic> tokenJson({String id = uid, bool verified = true}) {
  final expiry =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  final payload =
      base64Url.encode(utf8.encode(jsonEncode({'exp': expiry, 'sub': id})));
  return {
    'access_token': 'e30.$payload.signature',
    'token_type': 'bearer',
    'refresh_token': 'test-refresh-token',
    'expires_in': 3600,
    'user': userJson(id: id, verified: verified),
  };
}

Map<String, dynamic> profileJson({String avatar = '$uid/photo.jpg'}) => {
      'id': uid, 'full_name': 'Citizen Example', 'phone': '+923001234567',
      'cnic': '12345-1234567-1', 'locations': 'Fateh Jang', 'gender': 'Other',
      'profile_picture': avatar, 'created_at': '2026-11-17T00:00:00Z',
      // Even a stale or malicious extra email must not replace the auth email.
      'email': 'wrong@example.com',
    };

http.Response jsonResponse(Object? body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {
        'content-type': 'application/json',
        'x-supabase-api-version': '2024-01-01'
      },
    );

void main() {
  late SupabaseClient client;
  late AuthService auth;
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) respond;

  setUp(() {
    AppSession.instance.leavePreview();
    globalCitizenUser = null;
    requests = [];
    respond = (request) {
      if (request.url.path == '/auth/v1/token') {
        return jsonResponse(tokenJson());
      }
      if (request.url.path == '/rest/v1/profiles') {
        return jsonResponse(profileJson());
      }
      return jsonResponse({});
    };
    client = SupabaseClient(
      'https://auth.test',
      'test-anon-key',
      authOptions: const AuthClientOptions(
          autoRefreshToken: false, authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = await respond(request);
        return http.Response.bytes(response.bodyBytes, response.statusCode,
            headers: response.headers, request: request);
      }),
    );
    auth = AuthService(client: client);
  });

  tearDown(() async {
    AppSession.instance.leavePreview();
    globalCitizenUser = null;
    await client.dispose();
  });

  Future<void> signIn() async {
    await auth.signIn('citizen@example.com', ' Password123! ');
    requests.clear();
  }

  test('an interrupted profile write invalidates the old cached account',
      () async {
    await signIn();
    await fetchAndSetCitizenUser(uid, client: client);
    expect(globalCitizenUser, isNotNull);
    respond = (request) {
      if (request.url.path == '/rest/v1/rpc/update_profile') {
        throw http.ClientException('response lost after commit');
      }
      return jsonResponse({...profileJson(), 'full_name': 'Saved Citizen'});
    };
    await expectLater(
        updateCitizenProfile(
            userId: uid,
            fullName: 'Saved Citizen',
            phone: '+923001234567',
            location: 'Fateh Jang',
            client: client),
        throwsException);
    expect(globalCitizenUser, isNull);
    await fetchAndSetCitizenUser(uid, client: client);
    expect(globalCitizenUser?.fullName, 'Saved Citizen');
  });

  test('avatar writes never replay cached name or contact fields', () async {
    await signIn();
    respond = (request) => request.url.path == '/rest/v1/profiles'
        ? jsonResponse(
            {...profileJson(), 'full_name': 'Server Updated Citizen'})
        : jsonResponse(null);
    await updateCitizenAvatar(
        userId: uid, profilePicture: '$uid/avatar.png', client: client);
    final rpc = requests.singleWhere(
        (request) => request.url.path == '/rest/v1/rpc/update_avatar');
    expect(jsonDecode(rpc.body), {'p_profile_picture': '$uid/avatar.png'});
    expect(globalCitizenUser?.fullName, 'Server Updated Citizen');
  });

  test(
      'signup sends exact identity metadata and retains email without a session',
      () async {
    respond = (_) => jsonResponse(userJson(verified: false));
    final result = await auth.signUp(
        email: ' citizen@example.com ',
        password: ' Password123! ',
        fullName: ' Citizen Example ',
        phone: ' +923001234567 ',
        cnic: ' 12345-1234567-1 ',
        location: ' Fateh Jang ',
        gender: 'Other');
    expect(result.session, isNull);
    expect(auth.currentSession, isNull);
    expect(auth.pendingVerificationEmail, 'citizen@example.com');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['data'], {
      'full_name': 'Citizen Example',
      'phone': '+923001234567',
      'cnic': '12345-1234567-1',
      'locations': 'Fateh Jang',
      'gender': 'Other',
    });
    expect(body['password'], ' Password123! ');
    expect(requests.single.url.queryParameters['redirect_to'],
        'io.supabase.civicconnect://auth-callback/');
    requests.clear();
    // Another const-style service boundary shares the in-memory pending email.
    await AuthService(client: client).resendVerification();
    expect(requests.single.url.path, '/auth/v1/resend');
    expect(jsonDecode(requests.single.body)['type'], 'signup');
    expect(jsonDecode(requests.single.body)['email'], 'citizen@example.com');
  });

  test('password reset includes the app callback and preserves account privacy',
      () async {
    await auth.sendPasswordReset(' citizen@example.com ');
    expect(requests.single.url.path, '/auth/v1/recover');
    expect(jsonDecode(requests.single.body)['email'], 'citizen@example.com');
    expect(requests.single.url.queryParameters['redirect_to'],
        'io.supabase.civicconnect://auth-callback/');
  });

  test('password update uses the recovery session and exact password',
      () async {
    await signIn();
    respond = (_) => jsonResponse(userJson());
    await auth.updatePassword(' Password123! ');
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/auth/v1/user');
    expect(jsonDecode(requests.single.body)['password'], ' Password123! ');
    expect(requests.single.headers['Authorization'], startsWith('Bearer '));
  });

  test('a password update without a session never reaches the backend',
      () async {
    await expectLater(auth.updatePassword('Password123!'),
        throwsA(isA<AuthSessionMissingException>()));
    expect(requests, isEmpty);
  });

  test('preview rejects recovery password changes before a backend write',
      () async {
    await signIn();
    AppSession.instance.enterPreview();
    await expectLater(auth.updatePassword('Password123!'),
        throwsA(isA<AuthSessionMissingException>()));
    expect(requests, isEmpty);
  });

  test('pending verification cannot resume another signed-in account',
      () async {
    await signIn();
    respond = (_) => jsonResponse(userJson(verified: false));
    await auth.signUp(
        email: 'different@example.com',
        password: 'Password123!',
        fullName: 'Different Citizen',
        phone: '+923001234567',
        cnic: '12345-1234567-1',
        location: 'Fateh Jang',
        gender: 'Other');
    requests.clear();
    expect(await auth.refreshUser(), isNull);
    expect(requests, isEmpty);
  });

  test('unconfirmed sign-in retains the email for resend', () async {
    respond = (_) => jsonResponse(
        {'msg': 'Email not confirmed', 'code': 'email_not_confirmed'},
        status: 400);
    await expectLater(auth.signIn(' citizen@example.com ', 'Password123!'),
        throwsA(isA<AuthException>()));
    expect(auth.pendingVerificationEmail, 'citizen@example.com');
    expect(auth.currentSession, isNull);
  });

  test('verification refresh replaces stale cached confirmation and token',
      () async {
    respond = (_) => jsonResponse(tokenJson(verified: false));
    await auth.signIn('citizen@example.com', 'Password123!');
    expect(auth.currentUser!.emailConfirmedAt, isNull);
    respond = (_) => jsonResponse(tokenJson());
    final user = await auth.refreshUser();
    expect(user!.emailConfirmedAt, isNotNull);
    expect(auth.currentUser!.emailConfirmedAt, isNotNull);
  });

  test('unverified citizens cannot load a private profile', () async {
    respond = (_) => jsonResponse(tokenJson(verified: false));
    await signIn();
    await expectLater(fetchAndSetCitizenUser(uid, client: client),
        throwsA(isA<AuthSessionMissingException>()));
    expect(requests, isEmpty);
    await expectLater(prepareVerifiedCitizen(client.auth.currentUser!),
        throwsA(isA<AccountSetupException>()));
  });

  test(
      'own profile maps identity, auth email and relative avatar into the cache',
      () async {
    await signIn();
    await fetchAndSetCitizenUser(uid, client: client);
    expect(requests.single.url.path, '/rest/v1/profiles');
    expect(requests.single.url.queryParameters['id'], 'eq.$uid');
    expect(globalCitizenUser!.uid, uid);
    expect(globalCitizenUser!.email, 'citizen@example.com');
    expect(globalCitizenUser!.joinDate, '17/11/2026');
    expect(globalCitizenUser!.cnic, '12345-1234567-1');
    expect(globalCitizenUser!.displayPicture,
        'https://auth.test/storage/v1/object/public/profile-pictures/$uid/photo.jpg');
  });

  test('profile avatar cannot turn a remote URL into trusted media', () async {
    await signIn();
    respond = (_) =>
        jsonResponse(profileJson(avatar: 'https://untrusted.test/a.jpg'));
    await fetchAndSetCitizenUser(uid, client: client);
    expect(globalCitizenUser!.displayPicture, isEmpty);
  });

  test('a missing profile stays an error and can be fetched again', () async {
    await signIn();
    respond = (_) =>
        jsonResponse({'message': 'No row', 'code': 'PGRST116'}, status: 406);
    await expectLater(fetchAndSetCitizenUser(uid, client: client),
        throwsA(isA<PostgrestException>()));
    expect(globalCitizenUser, isNull);
    respond = (_) => jsonResponse(profileJson());
    await fetchAndSetCitizenUser(uid, client: client);
    expect(globalCitizenUser!.fullName, 'Citizen Example');
  });

  test('missing profile clears a previously cached citizen before retry',
      () async {
    await signIn();
    await fetchAndSetCitizenUser(uid, client: client);
    expect(globalCitizenUser, isNotNull);
    respond = (_) =>
        jsonResponse({'message': 'No row', 'code': 'PGRST116'}, status: 406);
    await expectLater(fetchAndSetCitizenUser(uid, client: client),
        throwsA(isA<PostgrestException>()));
    expect(globalCitizenUser, isNull);
  });

  test('preview blocks profile reads and writes before singleton access',
      () async {
    AppSession.instance.enterPreview();
    await expectLater(fetchAndSetCitizenUser(uid),
        throwsA(isA<AuthSessionMissingException>()));
    await expectLater(
        updateCitizenProfile(
            userId: uid,
            fullName: 'Citizen Example',
            phone: '+923001234567',
            location: 'Fateh Jang'),
        throwsA(isA<AuthSessionMissingException>()));
    expect(requests, isEmpty);
  });

  test('switching into preview while loading cannot populate the profile cache',
      () async {
    await signIn();
    final response = Completer<http.Response>();
    respond = (_) => response.future;
    final loading = fetchAndSetCitizenUser(uid, client: client);
    final assertion =
        expectLater(loading, throwsA(isA<AuthSessionMissingException>()));
    await Future<void>.delayed(Duration.zero);
    AppSession.instance.enterPreview();
    response.complete(jsonResponse(profileJson()));
    await assertion;
    expect(globalCitizenUser, isNull);
  });

  test('switching auth user while loading cannot populate the profile cache',
      () async {
    await signIn();
    final response = Completer<http.Response>();
    respond = (request) => request.url.path == '/rest/v1/profiles'
        ? response.future
        : jsonResponse(tokenJson(id: 'another-user'));
    final loading = fetchAndSetCitizenUser(uid, client: client);
    final assertion =
        expectLater(loading, throwsA(isA<AuthSessionMissingException>()));
    await Future<void>.delayed(Duration.zero);
    await auth.signIn('other@example.com', 'Password123!');
    response.complete(jsonResponse(profileJson()));
    await assertion;
    expect(globalCitizenUser, isNull);
  });

  test(
      'profile RPC uses exact allowed fields, preserves/removes avatar and reloads',
      () async {
    await signIn();
    for (final avatar in [null, '', '$uid/new-photo.jpg']) {
      requests.clear();
      await updateCitizenProfile(
          userId: uid,
          fullName: ' Citizen Example ',
          phone: ' +923001234567 ',
          location: ' Fateh Jang ',
          profilePicture: avatar,
          client: client);
      expect(requests.first.url.path, '/rest/v1/rpc/update_profile');
      expect(jsonDecode(requests.first.body), {
        'p_full_name': 'Citizen Example',
        'p_phone': '+923001234567',
        'p_locations': 'Fateh Jang',
        'p_profile_picture': avatar,
      });
      expect(requests.last.url.path, '/rest/v1/profiles');
      expect(globalCitizenUser!.fullName, 'Citizen Example');
    }
  });

  test('another user profile is rejected before a read or update is sent',
      () async {
    await signIn();
    await expectLater(fetchAndSetCitizenUser('another-user', client: client),
        throwsA(isA<AuthSessionMissingException>()));
    await expectLater(
        updateCitizenProfile(
            userId: 'another-user',
            fullName: 'Citizen',
            phone: '+923001234567',
            location: 'Fateh Jang',
            client: client),
        throwsA(isA<AuthSessionMissingException>()));
    expect(requests, isEmpty);
  });
}
