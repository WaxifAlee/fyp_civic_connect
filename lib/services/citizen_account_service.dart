import '../models/citizen_user.dart';
import 'supabase_client.dart';
import 'user_service.dart';

/// Account operations are independent of the screen and its editable draft.
class CitizenAccountService {
  const CitizenAccountService();

  String? get userId => SupabaseService.isConfigured
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  Future<CitizenUser> load() async {
    final id = userId;
    if (id == null) throw StateError('Sign in to view your account details.');
    await fetchAndSetCitizenUser(id);
    final profile = globalCitizenUser;
    if (profile == null || userId != id) {
      throw StateError('Your session has changed.');
    }
    return profile;
  }

  Future<void> save(
      {required String fullName,
      required String phone,
      required String location}) async {
    final id = userId;
    if (id == null) throw StateError('Sign in to save your account details.');
    await updateCitizenProfile(
        userId: id, fullName: fullName, phone: phone, location: location);
  }
}
