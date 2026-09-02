import 'package:intl/intl.dart';

final NumberFormat _rupeeFormat = NumberFormat.decimalPattern('en_IN');

/// Formats an integer paise amount as a rupee string, e.g. 371908 -> "₹3,719".
/// Money is always stored internally as integer paise; this is the only
/// place that should convert to a display string.
String formatPaise(int paise) {
  final rupees = paise ~/ 100;
  return '₹${_rupeeFormat.format(rupees)}';
}

/// Same as [formatPaise] but renders negative amounts with a minus sign
/// in front of the rupee symbol, e.g. -200000 -> "−₹2,000".
String formatPaiseSigned(int paise) {
  if (paise < 0) {
    return '−${formatPaise(paise.abs())}';
  }
  return formatPaise(paise);
}

/// Parses a user-typed rupee string (digits and optional separators) into
/// integer paise. Empty/invalid input returns 0.
int parseRupeesToPaise(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits) * 100;
}
