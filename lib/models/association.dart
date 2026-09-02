/// A multi-building residents' association the building can optionally
/// join. Purely a notice feed — fully decoupled from billing.
class Association {
  Association({
    this.code = '',
    this.name = '',
    this.buildingCount = 0,
    this.joined = false,
  });

  String code;
  String name;
  int buildingCount;
  bool joined;

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'buildingCount': buildingCount,
    'joined': joined,
  };

  factory Association.fromMap(Map<String, dynamic> map) => Association(
    code: map['code'] as String? ?? '',
    name: map['name'] as String? ?? '',
    buildingCount: map['buildingCount'] as int? ?? 0,
    joined: map['joined'] as bool? ?? false,
  );
}
