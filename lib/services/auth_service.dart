import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  static Future<void>? _googleInitialization;

  Stream<User?> authStateChanges() => _firebaseAuth.userChanges();

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

  Future<void> sendPasswordResetEmail(String email) =>
      _firebaseAuth.sendPasswordResetEmail(email: email.trim());

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

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      ..._defaultNotificationSettings,
    }, SetOptions(merge: true));
  }

  Future<UserCredential?> signInWithGoogle() async {
    late final UserCredential result;
    if (kIsWeb) {
      try {
        result = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (error) {
        if (error.code == 'web-context-canceled' ||
            error.code == 'popup-closed-by-user') {
          return null;
        }
        rethrow;
      }
    } else {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw FirebaseAuthException(
          code: 'google-sign-in-unsupported',
          message: 'Google sign-in is not supported on this device.',
        );
      }
      late final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          return null;
        }
        rethrow;
      }
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message:
              'Google sign-in is not configured for this app. Check the Firebase OAuth client setup.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      result = await _firebaseAuth.signInWithCredential(credential);
    }
    final user = result.user;
    if (user != null) {
      final profile = _profile(user.uid);
      final existing = await profile.get();
      final values = <String, dynamic>{
        'uid': user.uid,
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      if (user.email != null) values['email'] = user.email;
      if (user.displayName != null) values['displayName'] = user.displayName;
      if (user.photoURL != null) values['photoURL'] = user.photoURL;
      if (!existing.exists) {
        values.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'profileCompleted': false,
          ..._defaultNotificationSettings,
        });
      }
      await profile.set(values, SetOptions(merge: true));
    }
    return result;
  }

  static const _defaultNotificationSettings = <String, dynamic>{
    'notificationEnabled': true,
    'notificationTime': '08:00',
    'expiryReminder7Days': true,
    'expiryReminder3Days': true,
    'expiryReminder1Day': true,
    'expiryReminderOnExpiry': true,
    'budgetAlert70': true,
    'budgetAlert90': true,
    'budgetAlert100': true,
    'budgetAlertOver100': true,
  };

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<Map<String, dynamic>> getProfile(String uid) async =>
      (await _profile(uid).get()).data() ?? {};

  Stream<Map<String, dynamic>> watchProfile(String uid) =>
      _profile(uid).snapshots().map((snapshot) => snapshot.data() ?? {});

  Future<void> saveUsername(String uid, String username) async {
    final cleaned = username.trim();
    if (cleaned.length < 3 ||
        cleaned.length > 20 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleaned)) {
      throw const FormatException('Use 3–20 letters, numbers, or underscores.');
    }
    final usernameKey = cleaned.toLowerCase();
    await _profile(uid).set({
      'uid': uid,
      'username': cleaned,
      'usernameLower': usernameKey,
      'profileCompleted': true,
      'email': _firebaseAuth.currentUser?.email,
    }, SetOptions(merge: true));
    await _firebaseAuth.currentUser?.updateDisplayName(cleaned);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> values) =>
      _profile(uid).set(values, SetOptions(merge: true));

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
        'account-exists-with-different-credential' =>
          'An account already exists with this email using another sign-in method. Sign in with that method first.',
        'missing-google-id-token' =>
          'Google sign-in is not fully configured. Check the OAuth client setup in Firebase and Google Cloud.',
        'google-sign-in-unsupported' =>
          'Google sign-in is unavailable on this device.',
        'network-request-failed' =>
          'Network error. Please check your connection and try again.',
        'too-many-requests' =>
          'There have been too many attempts. Please wait a little and try again.',
        _ => 'Authentication failed. Please try again.',
      };
    }

    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled =>
          'Google sign-in was canceled.',
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is not configured for this app. Check its Android package name and OAuth client setup.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is unavailable. Check that it is enabled in Firebase Authentication.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Could not open Google sign-in. Please try again.',
        GoogleSignInExceptionCode.interrupted =>
          'Google sign-in was interrupted. Please try again.',
        GoogleSignInExceptionCode.userMismatch =>
          'Please choose the Google account currently signed in on this device.',
        GoogleSignInExceptionCode.unknownError =>
          'Google sign-in failed. Please try again.',
      };
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Your account may have been created, but the app could not save its profile. Check Firestore Rules to allow signed-in users to write their own users/{uid} document.',
        'unavailable' || 'network-request-failed' =>
          'Firebase is temporarily unavailable. Check your connection and try again.',
        'unauthenticated' =>
          'Firebase could not verify your session. Please sign in again.',
        _ => 'We could not connect to Firebase. Please try again.',
      };
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
