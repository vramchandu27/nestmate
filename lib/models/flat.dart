/// A second person in the same flat — a spouse, a parent, an adult child.
///
/// One flat routinely has two people who both want to see the bill and be
/// told when it's due. Before this, a flat held a single phone number, so
/// only one of them could sign in; sharing that login silently broke
/// notifications, because the device token was stored on the flat and
/// whoever logged in last overwrote the other's.
class CoResident {
  CoResident({required this.name, required this.phone});

  String name;
  String phone;

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  factory CoResident.fromMap(Map<String, dynamic> map) => CoResident(
    name: map['name'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
  );
}

/// A single flat in the building and its residents.
class Flat {
  Flat({
    required this.flatNumber,
    required this.residentName,
    required this.phone,
    this.tankerExempt = false,
    this.openingBalancePaise = 0,
    this.passwordSet = false,
    List<CoResident>? coResidents,
  }) : coResidents = coResidents ?? [];

  final String flatNumber;
  String residentName;

  /// The flat's primary number — the one the admin registered it against,
  /// and the one bills are addressed to.
  String phone;

  /// Everyone else in the flat who may also use the app. Each can sign in
  /// with their own number, sees the same bill, and is notified separately.
  List<CoResident> coResidents;

  /// Tanker-exempt flats pay common share only, no water charge.
  bool tankerExempt;

  /// Carried balance from prior months: positive = owed, negative = credit.
  int openingBalancePaise;

  bool passwordSet;

  /// Every number that may sign in for this flat, primary first.
  List<String> get allPhones => [
    phone,
    ...coResidents.map((c) => c.phone).where((p) => p.isNotEmpty),
  ].where((p) => p.isNotEmpty).toList();

  Map<String, dynamic> toMap() => {
    'flatNumber': flatNumber,
    'residentName': residentName,
    'phone': phone,
    'coResidents': coResidents.map((c) => c.toMap()).toList(),
    // Denormalized copy of [allPhones]. The security rules have to answer
    // "may this phone act for this flat?" and cannot read inside an array
    // of maps to do it — a flat list of strings is the one shape a rule
    // can test with `in`. Written on every save so it never drifts from
    // the coResidents it mirrors.
    'allPhones': allPhones,
    'tankerExempt': tankerExempt,
    'openingBalancePaise': openingBalancePaise,
    'passwordSet': passwordSet,
  };

  factory Flat.fromMap(Map<String, dynamic> map) => Flat(
    flatNumber: map['flatNumber'] as String,
    residentName: map['residentName'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    coResidents: (map['coResidents'] as List?)
        ?.map((c) => CoResident.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList(),
    tankerExempt: map['tankerExempt'] as bool? ?? false,
    openingBalancePaise: map['openingBalancePaise'] as int? ?? 0,
    passwordSet: map['passwordSet'] as bool? ?? false,
  );
}
