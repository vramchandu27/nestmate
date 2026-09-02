import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../models/bill.dart';
import '../models/building.dart';
import 'bill_message.dart';

/// Opens the device's SMS app pre-filled with a bill summary for [phone].
/// Works without any messaging app installed beyond the OS default, so
/// it's a reliable fallback wherever WhatsApp isn't an option.
Future<bool> sendBillViaSms({
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
  final number = phoneWithPlus(phone);
  // iOS's sms: scheme separates the body with '&', Android with '?'.
  final separator = (!kIsWeb && Platform.isIOS) ? '&' : '?';
  final uri = Uri.parse(
    'sms:$number${separator}body=${Uri.encodeComponent(message)}',
  );
  return launchUrl(uri);
}
