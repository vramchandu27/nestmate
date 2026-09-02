import 'advance.dart';
import 'bill.dart';
import 'expense.dart';
import 'water_month.dart';

/// Everything tracked for one billing month (e.g. "2026-07").
class MonthData {
  MonthData({
    required this.id,
    required this.label,
    List<Expense>? expenses,
    List<Advance>? advances,
    WaterMonthConfig? water,
    List<MeterReading>? readings,
    List<Bill>? bills,
    this.generated = false,
    this.generatedAt,
    this.flatCountAtGeneration,
    this.frozenTotalUsageLitres,
    this.frozenTotalTankerCostPaise,
  }) : expenses = expenses ?? [],
       advances = advances ?? [],
       water = water ?? WaterMonthConfig(),
       readings = readings ?? [],
       bills = bills ?? [];

  String id;
  String label;
  List<Expense> expenses;
  List<Advance> advances;
  WaterMonthConfig water;
  List<MeterReading> readings;
  List<Bill> bills;
  bool generated;
  DateTime? generatedAt;

  /// Snapshot of how many flats existed when bills were generated, and
  /// the water-calc totals that were actually used — frozen at generation
  /// time so a past month has a durable record of what was billed, even
  /// if flats or readings change afterward.
  int? flatCountAtGeneration;
  int? frozenTotalUsageLitres;
  int? frozenTotalTankerCostPaise;

  /// Sum of every common-pool expense this month (equal-split pool, §2b).
  int get commonPoolPaise => expenses.fold(0, (sum, e) => sum + e.amountPaise);

  MeterReading? readingFor(String flatNumber) {
    for (final r in readings) {
      if (r.flatNumber == flatNumber) return r;
    }
    return null;
  }

  Bill? billFor(String flatNumber) {
    for (final b in bills) {
      if (b.flatNumber == flatNumber) return b;
    }
    return null;
  }

  /// Only this doc's own fields — [expenses], [advances], [readings], and
  /// [bills] live in Firestore subcollections (see the schema note on
  /// [SocietyProvider]) and are read/written separately.
  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'water': water.toMap(),
    'generated': generated,
    'generatedAt': generatedAt?.millisecondsSinceEpoch,
    'flatCountAtGeneration': flatCountAtGeneration,
    'frozenTotalUsageLitres': frozenTotalUsageLitres,
    'frozenTotalTankerCostPaise': frozenTotalTankerCostPaise,
  };

  /// Builds a [MonthData] from just the month doc's own fields — callers
  /// must fill in [expenses]/[advances]/[readings]/[bills] separately from
  /// their own subcollection reads.
  factory MonthData.fromMap(Map<String, dynamic> map) => MonthData(
    id: map['id'] as String,
    label: map['label'] as String? ?? '',
    water: map['water'] != null
        ? WaterMonthConfig.fromMap(Map<String, dynamic>.from(map['water'] as Map))
        : null,
    generated: map['generated'] as bool? ?? false,
    generatedAt: map['generatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['generatedAt'] as int)
        : null,
    flatCountAtGeneration: map['flatCountAtGeneration'] as int?,
    frozenTotalUsageLitres: map['frozenTotalUsageLitres'] as int?,
    frozenTotalTankerCostPaise: map['frozenTotalTankerCostPaise'] as int?,
  );
}
