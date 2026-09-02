// Verifies the reported bug is actually fixed: the group-summary and
// individual-bill messages used to always say "July" because MonthData's
// label was a hardcoded seed value. Confirms SocietyProvider.setCurrentMonth
// updates that label, and the message builders pick it up.

import 'package:flutter_test/flutter_test.dart';

import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/utils/bill_message.dart';
import 'package:nestmate/utils/group_summary.dart';

void main() {
  test('setCurrentMonth updates the label used in outgoing messages', () {
    final society = SocietyProvider.mock();

    // Seed data starts as "July 2026" — confirm the starting point.
    expect(society.currentMonth.label, 'July 2026');

    society.setCurrentMonth(2026, 8);

    expect(society.currentMonth.label, 'August 2026');
    expect(society.currentMonth.id, '2026-08');

    final groupMessage = buildGroupSummaryMessage(
      building: society.building,
      month: society.currentMonth,
      flats: society.flats,
      waterCalc: society.waterCalc,
      exemptFlatNumbers: society.exemptFlatNumbers,
      commonSharePaisePerFlat: society.commonSharePaisePerFlat,
    );
    expect(groupMessage, contains('AUGUST month expenses'));
    expect(groupMessage, isNot(contains('JULY')));

    final bill = society.billForResident(society.flats.first.flatNumber);
    final billMessage = buildBillMessage(
      building: society.building,
      monthLabel: society.currentMonth.label,
      flatNumber: society.flats.first.flatNumber,
      residentName: society.flats.first.residentName,
      bill: bill,
    );
    expect(billMessage, contains('Your August 2026 maintenance bill'));
    expect(billMessage, isNot(contains('July')));
  });
}
