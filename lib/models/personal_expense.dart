/// A resident's own personal spending — entirely separate from the
/// building's shared finances (bills, common expenses, advances). Stored
/// per-user (`users/{uid}/personalExpenses`), never under `buildings/{id}`,
/// so it stays private to whoever created it.
const personalExpenseCategories = [
  'food',
  'transport',
  'shopping',
  'bills',
  'health',
  'entertainment',
  'other',
];

class PersonalExpense {
  PersonalExpense({
    required this.id,
    required this.name,
    required this.category,
    required this.amountPaise,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final String id;
  String name;

  /// One of [personalExpenseCategories].
  String category;
  int amountPaise;
  DateTime date;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'amountPaise': amountPaise,
    'date': date.millisecondsSinceEpoch,
  };

  factory PersonalExpense.fromMap(Map<String, dynamic> map) => PersonalExpense(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    category: map['category'] as String? ?? 'other',
    amountPaise: map['amountPaise'] as int? ?? 0,
    date: map['date'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
        : DateTime.now(),
  );
}
