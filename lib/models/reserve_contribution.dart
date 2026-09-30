/// One flat's payment into the building's reserve fund.
///
/// The reserve balance itself is a single running total on the building
/// ([Building.reserveFundPaise]) — these records are the audit trail
/// beside it, answering "who has actually paid in?", which a lone total
/// can't. They exist because residents pay at their own pace: a top-up is
/// rarely all flats on one day, and without per-flat records the admin has
/// no way to tell who is still outstanding.
class ReserveContribution {
  ReserveContribution({
    required this.id,
    required this.flatNumber,
    required this.residentName,
    required this.amountPaise,
    DateTime? collectedOn,
  }) : collectedOn = collectedOn ?? DateTime.now();

  final String id;
  final String flatNumber;

  /// Copied in at the time of collection rather than looked up on read, so
  /// the record still reads correctly after a flat changes hands.
  final String residentName;

  final int amountPaise;
  final DateTime collectedOn;

  Map<String, dynamic> toMap() => {
    'id': id,
    'flatNumber': flatNumber,
    'residentName': residentName,
    'amountPaise': amountPaise,
    'collectedOn': collectedOn.millisecondsSinceEpoch,
  };

  factory ReserveContribution.fromMap(Map<String, dynamic> map) =>
      ReserveContribution(
        id: map['id'] as String? ?? '',
        flatNumber: map['flatNumber'] as String? ?? '',
        residentName: map['residentName'] as String? ?? '',
        amountPaise: map['amountPaise'] as int? ?? 0,
        collectedOn: map['collectedOn'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['collectedOn'] as int)
            : null,
      );
}
