/// How an expense's cost is spread across flats.
enum ExpenseSplitRule { allFlats, specificFlats }

/// One recorded edit to an expense: what it was, what it became, and why.
///
/// Societies argue about money, and an admin who can silently change a
/// recorded figure is exactly what residents have reason to distrust. The
/// reason is mandatory at the point of editing, and this history is shown
/// to residents as well as the admin, so a changed number always carries
/// its own explanation.
class ExpenseChange {
  ExpenseChange({
    required this.changedAt,
    required this.reason,
    required this.previousName,
    required this.previousAmountPaise,
  });

  final DateTime changedAt;
  final String reason;
  final String previousName;
  final int previousAmountPaise;

  Map<String, dynamic> toMap() => {
    'changedAt': changedAt.millisecondsSinceEpoch,
    'reason': reason,
    'previousName': previousName,
    'previousAmountPaise': previousAmountPaise,
  };

  factory ExpenseChange.fromMap(Map<String, dynamic> map) => ExpenseChange(
    changedAt: map['changedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['changedAt'] as int)
        : DateTime.now(),
    reason: map['reason'] as String? ?? '',
    previousName: map['previousName'] as String? ?? '',
    previousAmountPaise: map['previousAmountPaise'] as int? ?? 0,
  );
}

/// A common-pool expense (watchman, electricity, trash, association fees,
/// CCTV, wifi, sump cleaning, etc). Equal-split across the flats in
/// [flatsInSplit]. Water/tanker cost is NOT modeled as an Expense — it is
/// billed by usage via [WaterMonthConfig] on the Water Calculator screen.
class Expense {
  Expense({
    required this.id,
    required this.name,
    required this.category,
    required this.amountPaise,
    this.splitRule = ExpenseSplitRule.allFlats,
    List<String>? specificFlatNumbers,
    this.paidByFlatNumber,
    this.fundedByReserve = false,
    this.receiptPhotoUrl,
    DateTime? createdAt,
    DateTime? spentOn,
    List<ExpenseChange>? changes,
  }) : specificFlatNumbers = specificFlatNumbers ?? const [],
       changes = changes ?? const [],
       createdAt = createdAt ?? DateTime.now(),
       spentOn = spentOn ?? createdAt ?? DateTime.now();

  final String id;
  String name;

  /// Drawn from the building's `commonCategories` picklist.
  String category;
  int amountPaise;
  ExpenseSplitRule splitRule;
  List<String> specificFlatNumbers;

  /// Null = paid to the collector normally. Set = this flat fronted the
  /// cost out of pocket, so it still splits across everyone AND this flat
  /// gets credited the full amount as an offset against its own bill.
  String? paidByFlatNumber;

  /// True = this expense is paid out of the building's reserve fund
  /// (see [SocietyProvider.addReserveContributions]) instead of being split across
  /// residents' bills this month — mutually exclusive with
  /// [paidByFlatNumber]. Excluded entirely from [MonthData.commonPoolPaise]
  /// and the WhatsApp group summary message.
  bool fundedByReserve;

  /// The receipt photo picked on the add-expense form, if any.
  String? receiptPhotoUrl;

  final DateTime createdAt;

  /// The day the money actually went out, which is rarely the day someone
  /// sat down to record it — a bill paid on the 3rd often gets entered on
  /// the 15th, and before this the 15th was all that was kept. The admin
  /// picks this on the form; [createdAt] stays as the untouched audit
  /// stamp of when the entry was made. Defaults to [createdAt] so every
  /// expense recorded before this field existed keeps the only date it had.
  DateTime spentOn;

  /// Every edit ever made to this expense, oldest first. Empty for one
  /// that has never been changed.
  final List<ExpenseChange> changes;

  /// Which flats this expense's cost is divided across.
  List<String> flatsInSplit(List<String> allFlatNumbers) {
    switch (splitRule) {
      case ExpenseSplitRule.allFlats:
        return allFlatNumbers;
      case ExpenseSplitRule.specificFlats:
        return specificFlatNumbers;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'amountPaise': amountPaise,
    'splitRule': splitRule.name,
    'specificFlatNumbers': specificFlatNumbers,
    'paidByFlatNumber': paidByFlatNumber,
    'fundedByReserve': fundedByReserve,
    'receiptPhotoUrl': receiptPhotoUrl,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'spentOn': spentOn.millisecondsSinceEpoch,
    'changes': changes.map((c) => c.toMap()).toList(),
    // Denormalized for the Cloud Function that notifies residents of a
    // change — it needs the reason without unpacking the whole list.
    'lastChangeReason': changes.isEmpty ? '' : changes.last.reason,
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    category: map['category'] as String? ?? '',
    amountPaise: map['amountPaise'] as int? ?? 0,
    splitRule: ExpenseSplitRule.values.byName(
      map['splitRule'] as String? ?? 'allFlats',
    ),
    specificFlatNumbers: (map['specificFlatNumbers'] as List?)?.cast<String>(),
    paidByFlatNumber: map['paidByFlatNumber'] as String?,
    fundedByReserve: map['fundedByReserve'] as bool? ?? false,
    receiptPhotoUrl: map['receiptPhotoUrl'] as String?,
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
    changes: (map['changes'] as List?)
        ?.map((c) => ExpenseChange.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList(),
    spentOn: map['spentOn'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['spentOn'] as int)
        : null,
  );
}
