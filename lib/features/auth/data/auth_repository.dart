import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<String?> getCompanyId() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims?['company_id'] as String?;
  }

  Future<void> refreshToken() async {
    await _auth.currentUser?.getIdTokenResult(true);
  }
}
