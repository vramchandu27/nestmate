import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/personal_expense.dart';

/// A resident's own personal spending — stored at
/// `users/{uid}/personalExpenses`, entirely separate from
/// [SocietyProvider]'s building-scoped data. Mirrors that provider's own
/// auth-driven listener-attach pattern (see its `_watchAuthState`): listens
/// to Firebase auth directly (not [AppProvider], to avoid a
/// provider-to-provider dependency) and attaches/detaches a Firestore
/// listener as the signed-in user changes.
class PersonalExpenseProvider extends ChangeNotifier {
  PersonalExpenseProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid != _attachedUid) {
        _attachedUid = user.uid;
        _sub?.cancel();
        _attachListener(user.uid);
      } else if (user == null && _attachedUid != null) {
        _attachedUid = null;
        _sub?.cancel();
        _sub = null;
        _expenses = [];
        notifyListeners();
      }
    });
  }

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription? _sub;
  String? _attachedUid;
  List<PersonalExpense> _expenses = [];

  List<PersonalExpense> get expenses => _expenses;
  int get totalPaise => _expenses.fold(0, (t, e) => t + e.amountPaise);

  /// Spending grouped by category — what the pie chart on
  /// [PersonalExpensesScreen] renders. Only categories with at least one
  /// expense appear; insertion order follows [personalExpenseCategories]
  /// so the chart/legend order stays stable as new expenses come in.
  Map<String, int> get totalsByCategory {
    final totals = <String, int>{};
    for (final category in personalExpenseCategories) {
      final sum = _expenses
          .where((e) => e.category == category)
          .fold<int>(0, (t, e) => t + e.amountPaise);
      if (sum > 0) totals[category] = sum;
    }
    return totals;
  }

  CollectionReference<Map<String, dynamic>> _expensesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('personalExpenses');

  void _attachListener(String uid) {
    _sub = _expensesRef(
      uid,
    ).orderBy('date', descending: true).snapshots().listen((snap) {
      _expenses = snap.docs
          .map((d) => PersonalExpense.fromMap(d.data()))
          .toList();
      notifyListeners();
    }, onError: (Object e) => debugPrint('PersonalExpenseProvider: $e'));
  }

  Future<void> addExpense(PersonalExpense expense) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _expensesRef(uid).doc(expense.id).set(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _expensesRef(uid).doc(id).delete();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
