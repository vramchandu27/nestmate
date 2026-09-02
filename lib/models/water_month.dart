/// One flat's meter reading for the month, in litres.
class MeterReading {
  MeterReading({
    required this.flatNumber,
    this.initialLitres = 0,
    this.finalLitres = 0,
    this.meterPhotoUrl,
    this.estimated = false,
  });

  final String flatNumber;
  int initialLitres;
  int finalLitres;

  /// No Firebase Storage yet — field exists so the shape is ready, but
  /// nothing captures a real photo until the walk-mode reader phase.
  String? meterPhotoUrl;

  /// True if this reading is a fallback estimate (missing/unreadable
  /// meter) rather than an actual reading. Not yet set by any screen —
  /// the walk-mode reader phase is what would offer that fallback.
  bool estimated;

  int get usageLitres {
    final diff = finalLitres - initialLitres;
    return diff > 0 ? diff : 0;
  }

  Map<String, dynamic> toMap() => {
    'flatNumber': flatNumber,
    'initialLitres': initialLitres,
    'finalLitres': finalLitres,
    'meterPhotoUrl': meterPhotoUrl,
    'estimated': estimated,
  };

  factory MeterReading.fromMap(Map<String, dynamic> map) => MeterReading(
    flatNumber: map['flatNumber'] as String,
    initialLitres: map['initialLitres'] as int? ?? 0,
    finalLitres: map['finalLitres'] as int? ?? 0,
    meterPhotoUrl: map['meterPhotoUrl'] as String?,
    estimated: map['estimated'] as bool? ?? false,
  );
}

/// The tanker inputs that drive this month's blended water rate.
/// Borewell water has no cost in the water calc — its electricity goes
/// into the common expense pool instead.
class WaterMonthConfig {
  WaterMonthConfig({this.tankerCount = 0, this.pricePerTankerPaise = 0});

  int tankerCount;
  int pricePerTankerPaise;

  int get totalTankerCostPaise => tankerCount * pricePerTankerPaise;

  Map<String, dynamic> toMap() => {
    'tankerCount': tankerCount,
    'pricePerTankerPaise': pricePerTankerPaise,
  };

  factory WaterMonthConfig.fromMap(Map<String, dynamic> map) =>
      WaterMonthConfig(
        tankerCount: map['tankerCount'] as int? ?? 0,
        pricePerTankerPaise: map['pricePerTankerPaise'] as int? ?? 0,
      );
}

/// Result of the blended-rate calculation across every flat's reading.
class WaterCalcResult {
  const WaterCalcResult({
    required this.totalUsageLitres,
    required this.totalTankerCostPaise,
  });

  final int totalUsageLitres;
  final int totalTankerCostPaise;

  /// Rate for DISPLAY only ("₹X per 1,000 L") — a double is fine here
  /// since it's never used to compute money. 0 when there's no usage yet.
  double get blendedRatePaisePer1000L => totalUsageLitres > 0
      ? (totalTankerCostPaise / totalUsageLitres) * 1000
      : 0.0;

  /// A flat's water charge, computed with pure integer arithmetic —
  /// `total_cost × its_litres ÷ total_litres` — so money is never derived
  /// from a floating-point rate. Per spec: keep money as integer paise
  /// internally, round only for display (and this doesn't even need a
  /// display-time round, since integer division already gives a whole
  /// paise value).
  int waterChargePaiseForLitres(int litres) {
    if (totalUsageLitres <= 0) return 0;
    return (totalTankerCostPaise * litres) ~/ totalUsageLitres;
  }
}

/// Blended tanker rate = total_tanker_cost ÷ total_litres_of_all_flats.
/// All flats' readings feed the denominator (even tanker-exempt ones,
/// since the shared meter measures all water drawn) — but each exempt
/// flat's own bill line is forced to 0 by the caller, per spec §2e.
WaterCalcResult computeWaterCalc(
  WaterMonthConfig config,
  List<MeterReading> readings,
) {
  final totalUsage = readings.fold<int>(0, (sum, r) => sum + r.usageLitres);
  return WaterCalcResult(
    totalUsageLitres: totalUsage,
    totalTankerCostPaise: config.totalTankerCostPaise,
  );
}
