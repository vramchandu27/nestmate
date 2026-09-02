/// One flat's share of an advance that needs to be recovered from it.
class AdvanceRecovery {
  AdvanceRecovery({required this.flatNumber, required this.amountPaise});

  final String flatNumber;
  int amountPaise;

  Map<String, dynamic> toMap() => {
    'flatNumber': flatNumber,
    'amountPaise': amountPaise,
  };

  factory AdvanceRecovery.fromMap(Map<String, dynamic> map) =>
      AdvanceRecovery(
        flatNumber: map['flatNumber'] as String,
        amountPaise: map['amountPaise'] as int? ?? 0,
      );
}

/// An advance the admin/collector paid out that isn't a shared common
/// expense — tracked separately and recovered from specific named flats
/// (added as a line on those flats' bills for the month it's applied).
class Advance {
  Advance({
    required this.id,
    required this.reason,
    required this.givenToName,
    required this.amountPaise,
    List<AdvanceRecovery>? recoveries,
    DateTime? createdAt,
  }) : recoveries = recoveries ?? [],
       createdAt = createdAt ?? DateTime.now();

  final String id;
  String reason;
  String givenToName;
  int amountPaise;
  List<AdvanceRecovery> recoveries;
  final DateTime createdAt;

  int get totalRecoveryPaise =>
      recoveries.fold(0, (sum, r) => sum + r.amountPaise);

  Map<String, dynamic> toMap() => {
    'id': id,
    'reason': reason,
    'givenToName': givenToName,
    'amountPaise': amountPaise,
    'recoveries': recoveries.map((r) => r.toMap()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Advance.fromMap(Map<String, dynamic> map) => Advance(
    id: map['id'] as String,
    reason: map['reason'] as String? ?? '',
    givenToName: map['givenToName'] as String? ?? '',
    amountPaise: map['amountPaise'] as int? ?? 0,
    recoveries: (map['recoveries'] as List? ?? [])
        .map((r) => AdvanceRecovery.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList(),
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
  );
}
