import '../models/bill.dart';
import '../models/building.dart';
import '../models/flat.dart';
import '../models/month_data.dart';
import 'money.dart';

/// Amount with the rupee sign dropped — used inside the per-flat breakdown
/// lines, where repeating "₹" on every term costs width a phone doesn't
/// have. The figure that matters, each flat's total, keeps the symbol.
String _plain(int paise) => formatPaise(paise).replaceFirst('₹', '');

/// A single announcement-style message summarizing the whole month's
/// expenses and how the per-flat amounts were worked out — meant to be
/// posted once to the building's own group chat, distinct from each
/// flat's individual bill message. Uses WhatsApp's own markup (`*bold*`,
/// `_italic_`) so it renders formatted once shared, not as plain text.
///
/// Every per-flat number comes from [billFor] — the same
/// `SocietyProvider.billForResident` resolver the resident's own dashboard
/// and the admin's bill-preview list already use, which returns the
/// *frozen* bill once bills are generated, or a live draft before that.
/// Recomputing these numbers independently here (as an earlier version of
/// this function did) let this message drift from what residents were
/// actually billed the moment anything changed after generation — an
/// edited expense, a corrected water reading — since a frozen bill by
/// design no longer reacts to that. Sourcing from the same resolver
/// everywhere means this message, the preview list, and what a resident
/// sees in-app can never show three different numbers for the same flat.
String buildGroupSummaryMessage({
  required Building building,
  required MonthData month,
  required List<Flat> flats,
  required List<String> exemptFlatNumbers,
  required Bill Function(String flatNumber) billFor,
}) {
  // Same for every flat by construction, so any one of them tells us the
  // per-flat rate for the header line below — sourced from the frozen bill
  // rather than recomputed, so it can never disagree with the per-flat
  // breakdown further down.
  final commonSharePaisePerFlat =
      flats.isEmpty ? 0 : billFor(flats.first.flatNumber).commonSharePaise;

  final buffer = StringBuffer()
    ..writeln('*${building.name} — ${month.label} Expenses*')
    ..writeln()
    ..writeln('*Water Tanker*')
    ..writeln(
      '${month.water.tankerCount} × ${formatPaise(month.water.pricePerTankerPaise)} = ${formatPaise(month.water.totalTankerCostPaise)}',
    )
    ..writeln()
    ..writeln('*Common Pool Expenses*');

  // Reserve-funded expenses are paid out of Building.reserveFundPaise, not
  // billed to residents this month — they must not appear here at all, not
  // just be excluded from the total (which MonthData.commonPoolPaise
  // already handles on its own).
  for (final e in month.expenses.where((e) => !e.fundedByReserve)) {
    final frontedNote = e.paidByFlatNumber != null
        ? ' (fronted by ${e.paidByFlatNumber})'
        : '';
    buffer.writeln('${e.name}: ${formatPaise(e.amountPaise)}$frontedNote');
  }
  buffer
    ..writeln('─────────────')
    ..writeln(
      // The dividend here is commonSharePaisePerFlat × flat count, not
      // month.commonPoolPaise directly — they can disagree if an expense
      // is edited after bills were generated without re-generating, and
      // this line's own arithmetic must always hold true by construction,
      // even in that edge case. The itemized list above is still a live
      // snapshot of this month's expenses either way.
      'Total: ${formatPaise(commonSharePaisePerFlat * flats.length)} ÷ ${flats.length} flats = ${formatPaise(commonSharePaisePerFlat)}/flat',
    );

  for (final a in month.advances) {
    buffer.writeln();
    buffer.writeln(
      'Advance given to ${a.givenToName} (${a.reason}): ${formatPaise(a.amountPaise)}',
    );
    if (a.recoveries.isNotEmpty) {
      final parts = a.recoveries
          .map((r) => '${r.flatNumber}: ${formatPaise(r.amountPaise)}')
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
    ..writeln('*Maintenance Amount Per Flat*')
    ..writeln('_(Common share + Water, billed by usage)_')
    ..writeln();

  // Each flat gets its total on its own line with the workings beneath it,
  // rather than one long equation. As a single line this ran to ~90
  // characters of unlabelled terms — "203: +₹1,000 + ₹1,328 + ₹599 −
  // ₹1,556 = *₹1,370*" — which WhatsApp wrapped wherever it liked on a
  // phone, and which gave a resident no way to tell what any of those
  // numbers were for. Short labelled lines keep the breaks under our
  // control and say what each figure means.
  for (final f in flats) {
    final bill = billFor(f.flatNumber);
    final isExempt = exemptFlatNumbers.contains(f.flatNumber);

    // A flat that fronted more than its own share ends up with a credit
    // rather than an amount due — showing that as a bare negative number
    // (e.g. "₹-7,986") reads as an error, so spell out what it means
    // instead of relying on formatPaise, which isn't built for negatives.
    final totalText = bill.amountDuePaise >= 0
        ? '*${formatPaise(bill.amountDuePaise)}*'
        : '*No payment due*';

    buffer
      ..writeln('*${f.flatNumber}*  $totalText')
      ..writeln(
        'common ${_plain(bill.commonSharePaise)} · water ${_plain(bill.waterChargePaise)}'
        '${isExempt ? ' _(tanker exempt)_' : ''}',
      );

    // Extra lines only when there is something to explain. The society
    // settles up every month — collect what was spent, repay whoever
    // fronted it — so most flats are just common + water and anything more
    // would be noise.
    //
    // Each on its own line rather than joined: worded plainly enough to be
    // unambiguous, two of them on one line would run past the width a
    // phone can show without wrapping.
    if (bill.offsetCreditsPaise > 0) {
      // This is the flat's own out-of-pocket spending on the building
      // coming off their bill — which is how they get it back. The earlier
      // wording, "paid back", read as though the society had already
      // handed them the money, which is exactly backwards.
      buffer.writeln(
        'minus ${_plain(bill.offsetCreditsPaise)} you spent for society',
      );
    }
    // Nothing carries forward under the monthly settle-up, so this is
    // normally zero and never printed. Kept for the case where a balance
    // is set anyway: without it the figures shown wouldn't add up to the
    // total beside them.
    if (bill.openingBalancePaise != 0) {
      buffer.writeln(
        'plus ${_plain(bill.openingBalancePaise.abs())} from last month',
      );
    }

    if (bill.amountDuePaise < 0) {
      buffer.writeln(
        '_${formatPaise(-bill.amountDuePaise)} owed back to this flat_',
      );
    }

    // A blank line after each flat, so sixteen of these read as sixteen
    // separate blocks rather than one wall of numbers — without it the
    // breakdown of one flat sits flush against the next flat's heading.
    buffer.writeln();
  }

  buffer
    ..writeln('━━━━━━━━━━━━━━━')
    ..writeln(
      'Please pay to: ${building.upiId} and share the screenshot to avoid any confusion.',
    )
    ..write('Thanks');

  return buffer.toString();
}
