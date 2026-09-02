/// How an expense's cost is spread across flats.
enum ExpenseSplitRule { allFlats, specificFlats }

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
    this.receiptPhotoUrl,
    DateTime? createdAt,
  }) : specificFlatNumbers = specificFlatNumbers ?? const [],
       createdAt = createdAt ?? DateTime.now();

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

  /// The receipt photo picked on the add-expense form, if any.
  String? receiptPhotoUrl;

  final DateTime createdAt;

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
    'receiptPhotoUrl': receiptPhotoUrl,
    'createdAt': createdAt.millisecondsSinceEpoch,
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
    receiptPhotoUrl: map['receiptPhotoUrl'] as String?,
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
  );
}
