import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_session.dart';
import '../models/citizen_user.dart';
import '../utils/validators.dart';
import 'supabase_client.dart';

/// Current authenticated citizen profile. Preview profiles never enter this cache.
CitizenUser? globalCitizenUser;

SupabaseClient _client(SupabaseClient? client) {
  if (client != null) return client;
  if (!SupabaseService.isConfigured) throw AuthSessionMissingException();
  return Supabase.instance.client;
}

User _requireCitizen(SupabaseClient client, String userId) {
  final user = client.auth.currentUser;
  if (AppSession.instance.isPreview ||
      client.auth.currentSession == null ||
      user == null ||
      user.id != userId ||
      user.emailConfirmedAt == null) {
    throw AuthSessionMissingException();
  }
  return user;
}

Future<void> fetchAndSetCitizenUser(String userId,
    {SupabaseClient? client}) async {
  // Check preview before touching the backend singleton.
  if (AppSession.instance.isPreview) throw AuthSessionMissingException();
  final backend = _client(client);
  _requireCitizen(backend, userId);
  globalCitizenUser = null;
  final data =
      await backend.from('profiles').select().eq('id', userId).single();
  final user = _requireCitizen(backend, userId);
  final date = DateTime.tryParse(data['created_at']?.toString() ?? '');
  String? text(String field) =>
      data[field] is String ? data[field] as String : null;
  final path = text('profile_picture') ?? '';
  final validPath = path.startsWith('$userId/') &&
      !path.contains(RegExp(r'[\\%?#]')) &&
      !path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..');
  globalCitizenUser = CitizenUser(
    uid: userId,
    fullName: text('full_name'),
    email: user.email,
    location: text('locations'),
    phone: text('phone'),
    displayPicture: validPath
        ? backend.storage.from('profile-pictures').getPublicUrl(path)
        : '',
    cnic: text('cnic'),
    gender: text('gender'),
    joinDate: date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
  );
}

Future<void> updateCitizenProfile({
  required String userId,
  required String fullName,
  required String phone,
  required String location,
  String? profilePicture,
  SupabaseClient? client,
}) async {
  if (AppSession.instance.isPreview) throw AuthSessionMissingException();
  final backend = _client(client);
  _requireCitizen(backend, userId);
  // An interrupted write may have committed. Never reuse the old snapshot.
  globalCitizenUser = null;
  await backend.rpc('update_profile', params: {
    'p_full_name': fullName.trim(),
    'p_phone': Validators.normalizePhone(phone),
    'p_locations': location.trim(),
    'p_profile_picture': profilePicture,
  });
  _requireCitizen(backend, userId);
  await fetchAndSetCitizenUser(userId, client: backend);
}

Future<void> updateCitizenAvatar(
    {required String userId,
    required String profilePicture,
    SupabaseClient? client}) async {
  if (AppSession.instance.isPreview) throw AuthSessionMissingException();
  final backend = _client(client);
  _requireCitizen(backend, userId);
  globalCitizenUser = null;
  await backend
      .rpc('update_avatar', params: {'p_profile_picture': profilePicture});
  _requireCitizen(backend, userId);
  await fetchAndSetCitizenUser(userId, client: backend);
}
