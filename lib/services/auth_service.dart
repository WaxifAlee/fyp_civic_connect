import 'package:firebase_auth/firebase_auth.dart';

/// Authentication boundary shared by sign-in and recovery surfaces.
class AuthService {
  const AuthService();

  Future<UserCredential> signIn(String email, String password) =>
      FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);
}
