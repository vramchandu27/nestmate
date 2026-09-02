/// A single flat in the building and its resident.
class Flat {
  Flat({
    required this.flatNumber,
    required this.residentName,
    required this.phone,
    this.tankerExempt = false,
    this.openingBalancePaise = 0,
    this.passwordSet = false,
  });

  final String flatNumber;
  String residentName;
  String phone;

  /// Tanker-exempt flats pay common share only, no water charge.
  bool tankerExempt;

  /// Carried balance from prior months: positive = owed, negative = credit.
  int openingBalancePaise;

  bool passwordSet;

  Map<String, dynamic> toMap() => {
    'flatNumber': flatNumber,
    'residentName': residentName,
    'phone': phone,
    'tankerExempt': tankerExempt,
    'openingBalancePaise': openingBalancePaise,
    'passwordSet': passwordSet,
  };

  factory Flat.fromMap(Map<String, dynamic> map) => Flat(
    flatNumber: map['flatNumber'] as String,
    residentName: map['residentName'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    tankerExempt: map['tankerExempt'] as bool? ?? false,
    openingBalancePaise: map['openingBalancePaise'] as int? ?? 0,
    passwordSet: map['passwordSet'] as bool? ?? false,
  );
}
