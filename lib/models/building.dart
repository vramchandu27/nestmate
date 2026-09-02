/// The single building this app manages, and its collection setup.
class Building {
  Building({
    this.name = '',
    this.adminName = '',
    this.adminPhone = '',
    this.collectorName = '',
    this.upiId = '',
    this.photoAdded = false,
    this.photoUrl,
    this.setupComplete = false,
    this.joinCode = '',
    this.defaultLang = 'en',
    this.waterMetered = true,
    List<String>? commonCategories,
    this.committeeEnabled = false,
    this.createdBy = '',
    this.currentMonthId = '',
    DateTime? createdAt,
  }) : commonCategories = commonCategories ?? const [
         'Watchman',
         'Common electricity',
         'Diesel',
         'CCTV',
         'Wifi',
         'Association fee',
         'Trash collection',
         'Sump cleaning',
         'Plumbing',
         'Other',
       ],
       createdAt = createdAt ?? DateTime.now();

  String name;
  String adminName;

  /// The single phone number bound to the admin seat for this building.
  /// Empty means unclaimed — the first phone to successfully log in as
  /// admin claims it (see [SocietyProvider.claimAdminIfUnbound]). Only
  /// [SocietyProvider.transferAdmin] can hand it to someone else — there
  /// is never more than one admin at a time.
  String adminPhone;

  /// The person residents actually pay via UPI — may differ from the admin.
  String collectorName;
  String upiId;

  /// Whether a cover photo has been set — kept alongside [photoUrl] as the
  /// UI status flag.
  bool photoAdded;
  String? photoUrl;
  bool setupComplete;

  /// Short code residents use to self-register against this building once
  /// multi-tenancy exists. Generated at setup time; not yet enforced
  /// anywhere since there's only ever one building in this mock.
  String joinCode;

  /// 'en' or 'te' — captured from whatever language the admin was using
  /// when they completed setup.
  String defaultLang;

  /// If false, water billing is skipped entirely for every flat.
  bool waterMetered;

  /// Picklist of common-expense categories for this building.
  List<String> commonCategories;

  bool committeeEnabled;
  String createdBy;
  final DateTime createdAt;

  /// Which `months/{monthId}` doc is "current" — persisted so a reload
  /// knows which month subcollection to attach listeners to (mirrors
  /// [SocietyProvider.setCurrentMonth], which can point this anywhere,
  /// not necessarily the real calendar month).
  String currentMonthId;

  Map<String, dynamic> toMap() => {
    'name': name,
    'adminName': adminName,
    'adminPhone': adminPhone,
    'collectorName': collectorName,
    'upiId': upiId,
    'photoAdded': photoAdded,
    'photoUrl': photoUrl,
    'setupComplete': setupComplete,
    'joinCode': joinCode,
    'defaultLang': defaultLang,
    'waterMetered': waterMetered,
    'commonCategories': commonCategories,
    'committeeEnabled': committeeEnabled,
    'createdBy': createdBy,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'currentMonthId': currentMonthId,
  };

  factory Building.fromMap(Map<String, dynamic> map) => Building(
    name: map['name'] as String? ?? '',
    adminName: map['adminName'] as String? ?? '',
    adminPhone: map['adminPhone'] as String? ?? '',
    collectorName: map['collectorName'] as String? ?? '',
    upiId: map['upiId'] as String? ?? '',
    photoAdded: map['photoAdded'] as bool? ?? false,
    photoUrl: map['photoUrl'] as String?,
    setupComplete: map['setupComplete'] as bool? ?? false,
    joinCode: map['joinCode'] as String? ?? '',
    defaultLang: map['defaultLang'] as String? ?? 'en',
    waterMetered: map['waterMetered'] as bool? ?? true,
    commonCategories: (map['commonCategories'] as List?)?.cast<String>(),
    committeeEnabled: map['committeeEnabled'] as bool? ?? false,
    createdBy: map['createdBy'] as String? ?? '',
    currentMonthId: map['currentMonthId'] as String? ?? '',
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
  );
}
