import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'We could not create your account. Please try again.',
      );
    }

    final displayName = email.trim().split('@').first;
    await user.updateDisplayName(displayName);

    await _firestore.collection('users').doc(user.uid).set({
      'name': displayName,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String friendlyAuthError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Please enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' => 'No account was found for that email.',
        'wrong-password' ||
        'invalid-credential' => 'The email or password is incorrect.',
        'email-already-in-use' =>
          'An account already exists with that email. Try logging in instead.',
        'weak-password' => 'Please use a stronger password.',
        'operation-not-allowed' =>
          'Email and password sign-up is not enabled. Enable it in Firebase Console under Authentication > Sign-in method.',
        'network-request-failed' =>
          'Network error. Please check your connection and try again.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Your account may have been created, but the app could not save its profile. Check Firestore Rules to allow signed-in users to write their own users/{uid} document.',
        'unavailable' ||
        'network-request-failed' =>
          'Firebase is temporarily unavailable. Check your connection and try again.',
        'unauthenticated' =>
          'Firebase could not verify your session. Please sign in again.',
        _ =>
          'Firebase error (${error.code}). Check your Firebase setup and try again.',
      };
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
