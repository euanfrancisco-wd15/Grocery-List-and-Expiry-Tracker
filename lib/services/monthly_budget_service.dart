import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MonthlyBudgetService {
  MonthlyBudgetService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static double budgetFromProfile(
    Map<String, dynamic> profile,
    DateTime month, {
    DateTime? today,
  }) {
    final monthBudgets = profile['monthlyBudgets'];
    if (monthBudgets is Map && monthBudgets[monthKey(month)] is num) {
      return (monthBudgets[monthKey(month)] as num).toDouble();
    }
    final currentMonth = today ?? DateTime.now();
    if (month.year == currentMonth.year && month.month == currentMonth.month) {
      return (profile['monthlyBudget'] as num?)?.toDouble() ?? 0;
    }
    return 0;
  }

  Future<void> saveBudget({
    required String userId,
    required DateTime month,
    required double amount,
  }) async {
    _verifyUser(userId);
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than zero.');
    }
    final reference = _firestore.collection('users').doc(userId);
    final key = monthKey(month);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final profile = snapshot.data() ?? <String, dynamic>{};
      final existing = profile['monthlyBudgets'];
      final budgets = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      budgets[key] = amount;
      transaction.set(reference, {
        'monthlyBudgets': budgets,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchExpensesForMonth({
    required String userId,
    required DateTime month,
  }) {
    _verifyUser(userId);
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .where(
          'purchaseDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('purchaseDate', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  static double sumExpenses(Iterable<Map<String, dynamic>> expenses) =>
      expenses.fold<double>(0, (total, expense) {
        final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
        return total + amount;
      });

  void _verifyUser(String requestedUserId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Sign in to view or update your budget.',
      );
    }
    if (uid != requestedUserId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'You can only access your own budget and expenses.',
      );
    }
  }
}
