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
        _salarySub?.cancel();
        _budgetsSub?.cancel();
        _attachListener(user.uid);
      } else if (user == null && _attachedUid != null) {
        _attachedUid = null;
        _sub?.cancel();
        _sub = null;
        _salarySub?.cancel();
        _salarySub = null;
        _budgetsSub?.cancel();
        _budgetsSub = null;
        _expenses = [];
        _salaryPaise = 0;
        _budgetsByMonth = {};
        _legacyBudgetsPaise = {};
        notifyListeners();
      }
    });
  }

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription? _sub;
  StreamSubscription? _salarySub;
  StreamSubscription? _budgetsSub;
  String? _attachedUid;
  List<PersonalExpense> _expenses = [];
  int _salaryPaise = 0;

  /// Explicitly-set budgets, keyed "YYYY-MM" -> category -> paise. A month
  /// only appears here if a budget was actually set *in* that month; every
  /// other month inherits (see [budgetForCategory]).
  Map<String, Map<String, int>> _budgetsByMonth = {};

  /// Budgets saved by the first version of this feature, before budgets
  /// became per-month (doc id was the bare category, with no year/month).
  /// Used as the fallback when no month-specific budget is found, so those
  /// earlier entries keep working instead of silently vanishing.
  Map<String, int> _legacyBudgetsPaise = {};

  List<PersonalExpense> get expenses => _expenses;

  /// The salary/income figure the resident entered themselves — purely
  /// self-reported, nothing to reconcile against. 0 until they set one.
  int get salaryPaise => _salaryPaise;

  static String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  /// The budget in force for [category] in the given month: whatever was
  /// last explicitly set that month or in any earlier one. So a budget set
  /// once keeps applying to later months without being re-entered, while
  /// changing it in a later month leaves earlier months untouched. An
  /// explicit 0 means "no budget this month" and deliberately stops the
  /// walk-back, rather than falling through to an older value.
  int? budgetForCategory(int year, int month, String category) {
    var y = year;
    var m = month;
    // Bounded at 10 years of months so a never-set category can't loop on.
    for (var i = 0; i < 120; i++) {
      final amount = _budgetsByMonth[_monthKey(y, m)]?[category];
      if (amount != null) return amount > 0 ? amount : null;
      m--;
      if (m < 1) {
        m = 12;
        y--;
      }
    }
    final legacy = _legacyBudgetsPaise[category];
    return (legacy != null && legacy > 0) ? legacy : null;
  }

  /// Every category's in-force budget for one month — what the budget
  /// progress bars render. Categories with no budget are left out.
  Map<String, int> effectiveBudgetsForMonth(int year, int month) {
    final result = <String, int>{};
    for (final category in personalExpenseCategories) {
      final amount = budgetForCategory(year, month, category);
      if (amount != null) result[category] = amount;
    }
    return result;
  }

  List<PersonalExpense> expensesForMonth(int year, int month) => _expenses
      .where((e) => e.date.year == year && e.date.month == month)
      .toList();

  int totalPaiseForMonth(int year, int month) => expensesForMonth(
    year,
    month,
  ).fold(0, (t, e) => t + e.amountPaise);

  /// What's left of [salaryPaise] after that month's spending — goes
  /// negative once spending exceeds it, which the UI shows as overspent
  /// rather than clamping to zero. Salary itself isn't month-specific (a
  /// resident sets one recurring figure), so this is the same salary
  /// counted down by whichever month is being viewed.
  int remainingPaiseForMonth(int year, int month) =>
      _salaryPaise - totalPaiseForMonth(year, month);

  /// Spending grouped by category for one month — what the pie chart on
  /// [PersonalExpensesScreen] renders. Only categories with at least one
  /// expense that month appear; insertion order follows
  /// [personalExpenseCategories] so the chart/legend order stays stable.
  Map<String, int> totalsByCategoryForMonth(int year, int month) {
    final monthExpenses = expensesForMonth(year, month);
    final totals = <String, int>{};
    for (final category in personalExpenseCategories) {
      final sum = monthExpenses
          .where((e) => e.category == category)
          .fold<int>(0, (t, e) => t + e.amountPaise);
      if (sum > 0) totals[category] = sum;
    }
    return totals;
  }

  CollectionReference<Map<String, dynamic>> _expensesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('personalExpenses');

  CollectionReference<Map<String, dynamic>> _budgetsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('personalBudgets');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  void _attachListener(String uid) {
    _sub = _expensesRef(
      uid,
    ).orderBy('date', descending: true).snapshots().listen((snap) {
      _expenses = snap.docs
          .map((d) => PersonalExpense.fromMap(d.data()))
          .toList();
      notifyListeners();
    }, onError: (Object e) => debugPrint('PersonalExpenseProvider: $e'));
    _salarySub = _userRef(uid).snapshots().listen((snap) {
      _salaryPaise = snap.data()?['monthlySalaryPaise'] as int? ?? 0;
      notifyListeners();
    }, onError: (Object e) => debugPrint('PersonalExpenseProvider salary: $e'));
    _budgetsSub = _budgetsRef(uid).snapshots().listen((snap) {
      final byMonth = <String, Map<String, int>>{};
      final legacy = <String, int>{};
      for (final d in snap.docs) {
        final data = d.data();
        final amount = data['amountPaise'] as int? ?? 0;
        final year = data['year'] as int?;
        final month = data['month'] as int?;
        final category = data['category'] as String?;
        if (year == null || month == null || category == null) {
          // Pre-per-month doc: its id was the bare category name.
          legacy[d.id] = amount;
          continue;
        }
        byMonth.putIfAbsent(_monthKey(year, month), () => {})[category] =
            amount;
      }
      _budgetsByMonth = byMonth;
      _legacyBudgetsPaise = legacy;
      notifyListeners();
    }, onError: (Object e) => debugPrint('PersonalExpenseProvider budgets: $e'));
  }

  Future<void> addExpense(PersonalExpense expense) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _expensesRef(uid).doc(expense.id).set(expense.toMap());
  }

  Future<void> updateExpense(PersonalExpense expense) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _expensesRef(uid).doc(expense.id).set(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _expensesRef(uid).doc(id).delete();
  }

  /// The resident's own self-reported income — nothing to reconcile
  /// against, just a figure they set so [remainingPaiseForMonth] has
  /// something to count down from as they log expenses.
  Future<void> setSalary(int paise) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _userRef(
      uid,
    ).set({'monthlySalaryPaise': paise}, SetOptions(merge: true));
  }

  /// Sets this category's spending limit for one specific month. One doc
  /// per month+category, so setting one never disturbs another category or
  /// another month. A [paise] of 0 is stored rather than deleted — that's
  /// what records "no budget *this* month" as a deliberate choice, instead
  /// of silently inheriting an older month's figure (see
  /// [budgetForCategory]).
  Future<void> setCategoryBudget(
    int year,
    int month,
    String category,
    int paise,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _budgetsRef(uid).doc('${_monthKey(year, month)}_$category').set({
      'year': year,
      'month': month,
      'category': category,
      'amountPaise': paise,
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sub?.cancel();
    _salarySub?.cancel();
    _budgetsSub?.cancel();
    super.dispose();
  }
}
