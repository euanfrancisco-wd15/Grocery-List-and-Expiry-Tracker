import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grocery.dart';

class GroceryService {
  GroceryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String describeError(Object error, {required String action}) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firebase denied permission to $action. Update Firestore Rules to allow signed-in users to read and write users/{uid}/groceries/{groceryId}, where uid matches request.auth.uid.',
        'unauthenticated' =>
          'Your sign-in session has expired. Sign out and sign in again.',
        'unavailable' =>
          'Firestore is temporarily unavailable. Check your connection and try again.',
        'failed-precondition' =>
          'Firestore could not complete the request. Check the Firebase Console for a required index or database configuration.',
        _ => 'Firestore error (${error.code}) while trying to $action.',
      };
    }

    return 'An unexpected error occurred while trying to $action.';
  }

  CollectionReference<Map<String, dynamic>> _groceriesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('groceries');
  }

  Stream<List<Grocery>> watchGroceries(String userId) {
    return _groceriesRef(userId)
        .orderBy('expirationDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Grocery.fromFirestore(doc)).toList(),
        );
  }

  Future<void> addGrocery({
    required String userId,
    required Grocery grocery,
  }) async {
    await _groceriesRef(userId).add({
      ...grocery.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGrocery({
    required String userId,
    required Grocery grocery,
  }) async {
    await _groceriesRef(userId).doc(grocery.id).update({
      ...grocery.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGrocery({
    required String userId,
    required String groceryId,
  }) {
    return _groceriesRef(userId).doc(groceryId).delete();
  }
}
