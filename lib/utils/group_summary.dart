import '../models/building.dart';
import '../models/flat.dart';
import '../models/month_data.dart';
import '../models/water_month.dart';

/// A single announcement-style message summarizing the whole month's
/// expenses and how the per-flat amounts were worked out — meant to be
/// posted once to the building's own group chat, distinct from each
/// flat's individual bill message. Numbers are computed live from the
/// current month's data, not hand-typed.
String buildGroupSummaryMessage({
  required Building building,
  required MonthData month,
  required List<Flat> flats,
  required WaterCalcResult waterCalc,
  required List<String> exemptFlatNumbers,
  required int commonSharePaisePerFlat,
}) {
  String rupees(int paise) => (paise ~/ 100).toString();

  final nonExemptCount = flats.length - exemptFlatNumbers.length;
  final waterPerFlatPaise = nonExemptCount > 0
      ? waterCalc.totalTankerCostPaise ~/ nonExemptCount
      : 0;
  final monthWord = month.label.split(' ').first.toUpperCase();

  final buffer = StringBuffer()
    ..writeln('Hello all')
    ..writeln('$monthWord month expenses (Specific to our block)')
    ..writeln(
      'Water tanker: ${month.water.tankerCount}*${rupees(month.water.pricePerTankerPaise)}=${rupees(month.water.totalTankerCostPaise)} /-',
    )
    ..writeln();

  for (final e in month.expenses) {
    buffer.writeln('${e.name}: ${rupees(e.amountPaise)} /-');
  }
  for (final a in month.advances) {
    buffer.writeln(
      'Advance given to ${a.givenToName} (${a.reason}): ${rupees(a.amountPaise)} /-',
    );
    if (a.recoveries.isNotEmpty) {
      final parts = a.recoveries
          .map((r) => '${r.flatNumber}: ${rupees(r.amountPaise)}')
          .join(', ');
      buffer.writeln('  ($parts will be recovered)');
    }
  }

  buffer
    ..writeln()
    ..writeln(
      'Flats: ${flats.length} (${flats.map((f) => f.flatNumber).join(', ')})',
    )
    ..writeln();

  if (nonExemptCount > 0) {
    final exceptClause = exemptFlatNumbers.isEmpty
        ? ''
        : ' Except ${exemptFlatNumbers.join(', ')}';
    buffer
      ..writeln('Water Tanker Amount ($nonExemptCount Flats$exceptClause):')
      ..writeln(
        '${rupees(waterCalc.totalTankerCostPaise)}÷$nonExemptCount = ${rupees(waterPerFlatPaise)} /- (per flat)',
      )
      ..writeln();
  }

  buffer.writeln(
    'Per flat Common maintenance (${flats.length} flats): ${rupees(month.commonPoolPaise)}/${flats.length} = Rs. ${rupees(commonSharePaisePerFlat)} /-',
  );

  if (exemptFlatNumbers.isNotEmpty) {
    buffer.writeln(
      '${exemptFlatNumbers.join(' & ')} Flat amount: ${rupees(commonSharePaisePerFlat)} /-',
    );
  }
  buffer.writeln(
    'Remaining all flats Amount per Flat: ${rupees(commonSharePaisePerFlat + waterPerFlatPaise)} /-',
  );

  buffer
    ..writeln()
    ..writeln(
      'Please pay to: ${building.upiId} and share the screenshot to avoid any confusion.',
    )
    ..write('Thanks');

  return buffer.toString();
}
