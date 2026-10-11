import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/grocery.dart';
import 'grocery_image_service.dart';

class GroceryService {
  GroceryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _authenticatedUid(String requestedUid) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Sign in before accessing grocery records.',
      );
    }
    if (requestedUid != currentUid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message:
            'The requested grocery owner does not match the signed-in user.',
      );
    }
    return currentUid;
  }

  String describeError(Object error, {required String action}) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore blocked this save. It writes both the grocery and its budget record. Publish this project\'s firestore.rules and allow signed-in users to write under their own users/{uid}/groceries and users/{uid}/expenses paths.',
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

  CollectionReference<Map<String, dynamic>> _expensesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('expenses');

  String createGroceryId(String userId) =>
      _groceriesRef(_authenticatedUid(userId)).doc().id;

  Stream<List<Grocery>> watchGroceries(String userId) {
    final ownerUid = _authenticatedUid(userId);
    return _groceriesRef(ownerUid)
        .orderBy('expirationDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Grocery.fromFirestore(doc)).toList(),
        );
  }

  Future<List<Grocery>> getGroceries(String userId) async {
    final ownerUid = _authenticatedUid(userId);
    final snapshot = await _groceriesRef(ownerUid).get();
    return snapshot.docs.map((doc) => Grocery.fromFirestore(doc)).toList();
  }

  Future<void> addGrocery({
    required String userId,
    required Grocery grocery,
  }) async {
    final ownerUid = _authenticatedUid(userId);
    final groceryRef = grocery.id.isEmpty
        ? _groceriesRef(ownerUid).doc()
        : _groceriesRef(ownerUid).doc(grocery.id);
    final batch = _firestore.batch();
    batch.set(groceryRef, {
      ...grocery.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_expensesRef(ownerUid).doc(groceryRef.id), {
      'userId': ownerUid,
      'groceryId': groceryRef.id,
      'name': grocery.name,
      'description': grocery.name,
      'amount': grocery.totalCost,
      'category': grocery.category,
      'date': Timestamp.fromDate(grocery.purchaseDate),
      'purchaseDate': Timestamp.fromDate(grocery.purchaseDate),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateGrocery({
    required String userId,
    required Grocery grocery,
  }) async {
    final ownerUid = _authenticatedUid(userId);
    final batch = _firestore.batch();
    batch.update(_groceriesRef(ownerUid).doc(grocery.id), {
      ...grocery.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_expensesRef(ownerUid).doc(grocery.id), {
      'userId': ownerUid,
      'groceryId': grocery.id,
      'name': grocery.name,
      'description': grocery.name,
      'amount': grocery.totalCost,
      'category': grocery.category,
      'date': Timestamp.fromDate(grocery.purchaseDate),
      'purchaseDate': Timestamp.fromDate(grocery.purchaseDate),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteGrocery({
    required String userId,
    required String groceryId,
  }) async {
    final ownerUid = _authenticatedUid(userId);
    final reference = _groceriesRef(ownerUid).doc(groceryId);
    final data = (await reference.get()).data();
    final linkedExpenses = await _expensesRef(
      ownerUid,
    ).where('groceryId', isEqualTo: groceryId).get();
    final batch = _firestore.batch()..delete(reference);
    final expenseIds = linkedExpenses.docs.map((expense) => expense.id).toSet()
      ..add(groceryId);
    for (final expenseId in expenseIds) {
      batch.delete(_expensesRef(ownerUid).doc(expenseId));
    }
    await batch.commit();
    try {
      await GroceryImageService().deleteLocal(data?['imagePath'] as String?);
    } on Object {
      // Grocery deletion should succeed even if local photo cleanup fails.
    }
  }
}
