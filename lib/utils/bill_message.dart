import '../models/bill.dart';
import '../models/building.dart';
import 'money.dart';

/// Plain-text bill summary shared by the WhatsApp and SMS send actions.
String buildBillMessage({
  required Building building,
  required String monthLabel,
  required String flatNumber,
  required String residentName,
  required Bill bill,
}) {
  final buffer = StringBuffer()
    ..writeln('Hi $residentName,')
    ..writeln()
    ..writeln(
      'Your $monthLabel maintenance bill for Flat $flatNumber is ready.',
    )
    ..writeln();

  if (bill.openingBalancePaise != 0) {
    buffer.writeln(
      'Opening balance: ${formatPaiseSigned(bill.openingBalancePaise)}',
    );
  }
  buffer.writeln('Water charge: ${formatPaise(bill.waterChargePaise)}');
  buffer.writeln('Common share: ${formatPaise(bill.commonSharePaise)}');
  if (bill.offsetCreditsPaise > 0) {
    buffer.writeln('Credits: -${formatPaise(bill.offsetCreditsPaise)}');
  }

  buffer
    ..writeln()
    ..writeln('Amount due: ${formatPaise(bill.amountDuePaise)}')
    ..writeln()
    ..writeln('Pay via UPI: ${building.upiId}')
    ..writeln()
    ..write('— ${building.name}');

  return buffer.toString();
}

/// Digits-only phone, no leading '+' — the format wa.me links expect.
String phoneDigitsOnly(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

/// Digits with a leading '+' preserved when present — the format the
/// device's native `sms:`/`tel:` handlers expect for a full international
/// number.
String phoneWithPlus(String phone) {
  final digits = phoneDigitsOnly(phone);
  return phone.trim().startsWith('+') ? '+$digits' : digits;
}
