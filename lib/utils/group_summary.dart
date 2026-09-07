import '../models/building.dart';
import '../models/flat.dart';
import '../models/month_data.dart';
import '../models/water_month.dart';

/// A single announcement-style message summarizing the whole month's
/// expenses and how the per-flat amounts were worked out — meant to be
/// posted once to the building's own group chat, distinct from each
/// flat's individual bill message. Numbers are computed live from the
/// current month's data, not hand-typed. Uses WhatsApp's own markup
/// (`*bold*`, `_italic_`) so it renders formatted once shared, not as
/// plain text.
///
/// Water is billed by actual usage (see [WaterCalcResult.waterChargePaiseForLitres])
/// — never split equally by flat count, since two flats can legitimately
/// use very different amounts of water. [waterChargePaiseFor] is how this
/// message gets each flat's real charge without depending on
/// SocietyProvider directly (utils stays provider-free).
String buildGroupSummaryMessage({
  required Building building,
  required MonthData month,
  required List<Flat> flats,
  required WaterCalcResult waterCalc,
  required List<String> exemptFlatNumbers,
  required int commonSharePaisePerFlat,
  required int Function(String flatNumber) waterChargePaiseFor,
}) {
  String rupees(int paise) => (paise ~/ 100).toString();

  final buffer = StringBuffer()
    ..writeln('🏢 *${building.name} — ${month.label} Expenses*')
    ..writeln()
    ..writeln('💧 *Water Tanker*')
    ..writeln(
      '${month.water.tankerCount} × ₹${rupees(month.water.pricePerTankerPaise)} = ₹${rupees(month.water.totalTankerCostPaise)}',
    )
    ..writeln()
    ..writeln('🔧 *Common Pool Expenses*');

  for (final e in month.expenses) {
    buffer.writeln('${e.name}: ₹${rupees(e.amountPaise)}');
  }
  buffer
    ..writeln('─────────────')
    ..writeln(
      'Total: ₹${rupees(month.commonPoolPaise)} ÷ ${flats.length} flats = ₹${rupees(commonSharePaisePerFlat)}/flat',
    );

  for (final a in month.advances) {
    buffer.writeln();
    buffer.writeln(
      'Advance given to ${a.givenToName} (${a.reason}): ₹${rupees(a.amountPaise)}',
    );
    if (a.recoveries.isNotEmpty) {
      final parts = a.recoveries
          .map((r) => '${r.flatNumber}: ₹${rupees(r.amountPaise)}')
          .join(', ');
      buffer.writeln('  ($parts will be recovered)');
    }
  }

  buffer
    ..writeln()
    ..writeln(
      'Flats: ${flats.length} (${flats.map((f) => f.flatNumber).join(', ')})',
    )
    ..writeln()
    ..writeln('━━━━━━━━━━━━━━━')
    ..writeln('📋 *Maintenance Amount Per Flat*')
    ..writeln('_(Common share + Water, billed by usage)_')
    ..writeln();

  for (final f in flats) {
    final isExempt = exemptFlatNumbers.contains(f.flatNumber);
    final waterPaise = isExempt ? 0 : waterChargePaiseFor(f.flatNumber);
    final total = commonSharePaisePerFlat + waterPaise;
    final exemptNote = isExempt ? ' (tanker exempt)' : '';
    buffer.writeln(
      '${f.flatNumber}: ₹${rupees(commonSharePaisePerFlat)} + ₹${rupees(waterPaise)} = *₹${rupees(total)}*$exemptNote',
    );
  }

  buffer
    ..writeln()
    ..writeln('━━━━━━━━━━━━━━━')
    ..writeln(
      'Please pay to: ${building.upiId} and share the screenshot to avoid any confusion.',
    )
    ..write('Thanks 🙏');

  return buffer.toString();
}
