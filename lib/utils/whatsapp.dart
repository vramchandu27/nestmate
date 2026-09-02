import 'package:url_launcher/url_launcher.dart';

import '../models/bill.dart';
import '../models/building.dart';
import 'bill_message.dart';

/// Opens a WhatsApp chat pre-filled with a bill summary for [phone].
///
/// There is no way to bulk-send WhatsApp messages from a plain Flutter
/// app — that needs WhatsApp's paid Business API, which runs server-side
/// and requires Meta business verification. This opens one chat at a
/// time, pre-filled, for the admin to review and hit send themselves.
Future<bool> sendBillViaWhatsApp({
  required String phone,
  required Building building,
  required String monthLabel,
  required String flatNumber,
  required String residentName,
  required Bill bill,
}) {
  final message = buildBillMessage(
    building: building,
    monthLabel: monthLabel,
    flatNumber: flatNumber,
    residentName: residentName,
    bill: bill,
  );
  final digits = phoneDigitsOnly(phone);
  final uri = Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens WhatsApp pre-filled with [message] but no fixed recipient, so the
/// admin picks any chat — including a group — to post it to. This is how
/// a one-off building-wide announcement (as opposed to a per-flat bill)
/// gets sent, since there's no way to address a specific WhatsApp group
/// programmatically without their Business API.
Future<bool> sendTextViaWhatsApp(String message) {
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
