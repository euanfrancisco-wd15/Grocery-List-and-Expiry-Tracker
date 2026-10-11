import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseService {
  ExpenseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _expenses(String userId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
      );
    }
    if (uid != userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _firestore.collection('users').doc(uid).collection('expenses');
  }

  Future<void> saveManualExpense({
    required String userId,
    String? expenseId,
    required String description,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    if (description.trim().isEmpty ||
        category.trim().isEmpty ||
        !amount.isFinite ||
        amount <= 0) {
      throw ArgumentError('Enter a description and a positive amount.');
    }
    final collection = _expenses(userId);
    final reference = expenseId == null
        ? collection.doc()
        : collection.doc(expenseId);
    final existing = expenseId == null ? null : await reference.get();
    if (existing?.data()?['groceryId'] != null) {
      throw StateError(
        'Grocery purchase expenses must be changed from the grocery item.',
      );
    }
    await reference.set({
      'userId': _auth.currentUser!.uid,
      'description': description.trim(),
      'name': description.trim(),
      'category': category.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'purchaseDate': Timestamp.fromDate(date),
      'source': 'manual',
      if (existing?.exists != true) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteManualExpense({
    required String userId,
    required String expenseId,
  }) async {
    final reference = _expenses(userId).doc(expenseId);
    final snapshot = await reference.get();
    if (snapshot.data()?['groceryId'] != null) {
      throw StateError(
        'Remove or update grocery purchase expenses from the grocery item.',
      );
    }
    await reference.delete();
  }
}
