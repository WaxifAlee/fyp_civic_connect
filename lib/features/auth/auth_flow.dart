import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_civic_connect/services/user_service.dart';

class AccountSetupException implements Exception {
  const AccountSetupException(this.message);
  final String message;
}

/// Finishes pending registration atomically. This is shared by startup, login,
/// and verification so verifying in another browser does not strand an account.
Future<void> prepareVerifiedCitizen(User user) async {
  if (!user.emailVerified) {
    throw const AccountSetupException('Verify your email to continue.');
  }
  await user.getIdToken(true);
  final firestore = FirebaseFirestore.instance;
  final pending = firestore.collection('pending_users').doc(user.uid);
  final active = firestore.collection('users').doc(user.uid);
  await firestore.runTransaction<void>((transaction) async {
    final pendingSnapshot = await transaction.get(pending);
    final activeSnapshot = await transaction.get(active);
    if (pendingSnapshot.exists) {
      final data = Map<String, dynamic>.from(pendingSnapshot.data()!);
      // Legacy registrations stored this credential. Never propagate it.
      data.remove('confirm_password');
      data['uid'] = user.uid;
      data['email_verified'] = true;
      data['updated_at'] = FieldValue.serverTimestamp();
      transaction.set(active, data, SetOptions(merge: true));
      transaction.delete(pending);
    } else if (!activeSnapshot.exists) {
      throw const AccountSetupException(
        'Your sign-in exists, but your citizen profile is missing. '
        'Return to registration if you still have it open, or try again later.',
      );
    }
  });
  globalCitizenUser = null;
  await fetchAndSetCitizenUser(user.uid);
}

String friendlyAuthError(Object error) {
  if (error is AccountSetupException) return error.message;
  if (error is FirebaseAuthException) {
    switch (error.code.replaceFirst('auth/', '')) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
      case 'user-not-found':
        return 'We couldn’t sign you in with those details. Check your email and password.';
      case 'invalid-email':
        return 'Check your email address and try again.';
      case 'email-already-in-use':
        return 'This email is already in use. Sign in or reset your password.';
      case 'weak-password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'user-disabled':
        return 'This account is unavailable. Contact the service administrator.';
      case 'too-many-requests':
        return 'There have been too many attempts. Please wait before trying again.';
      case 'network-request-failed':
        return 'We couldn’t connect. Check your internet connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'operation-not-allowed':
        return 'Email sign-in is currently unavailable. Please try again later.';
    }
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'We couldn’t connect. Check your connection and try again.';
      case 'permission-denied':
        return 'Your account details couldn’t be saved or loaded. Please try again later.';
    }
  }
  return 'Something interrupted this step. Please try again.';
}
