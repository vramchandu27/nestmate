import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/bill.dart';
import '../models/expense.dart';
import '../models/water_month.dart';

final NumberFormat _rupeeFormat = NumberFormat.decimalPattern('en_IN');

/// Same rounding/grouping as [formatPaise], but spelled "Rs." instead of
/// "₹" — the pdf package's base Helvetica font has no rupee-sign glyph, so
/// rendering the real symbol would print as a blank box.
String _rupees(int paise) => 'Rs. ${_rupeeFormat.format(paise ~/ 100)}';

/// Builds a one-page maintenance statement PDF for a single flat's bill —
/// everything already shown on [BillBreakdownScreen], laid out for saving
/// or sharing rather than just on-screen viewing.
Future<Uint8List> buildStatementPdf({
  required String buildingName,
  required String monthLabel,
  required String flatNumber,
  required String residentName,
  required bool tankerExempt,
  required MeterReading? reading,
  required Bill bill,
  required List<Expense> creditExpenses,
}) async {
  final doc = pw.Document();
  final sectionStyle = pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.blueGrey800,
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              buildingName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Maintenance Statement',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  monthLabel,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Flat $flatNumber'
                  '${residentName.isNotEmpty ? ' · $residentName' : ''}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            if (!tankerExempt) ...[
              pw.Text('Water Meter', style: sectionStyle),
              pw.SizedBox(height: 8),
              _kv('Initial reading', '${reading?.initialLitres ?? 0} L'),
              _kv('Final reading', '${reading?.finalLitres ?? 0} L'),
              _kv('Usage this month', '${reading?.usageLitres ?? 0} L'),
              pw.SizedBox(height: 18),
            ],

            pw.Text('Bill Breakdown', style: sectionStyle),
            pw.SizedBox(height: 8),
            if (bill.openingBalancePaise != 0)
              _kv('Opening balance', _rupees(bill.openingBalancePaise)),
            if (!tankerExempt)
              _kv('Water tanker share', _rupees(bill.waterChargePaise)),
            _kv('Common maintenance', _rupees(bill.commonSharePaise)),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.grey300),
            _kv('Subtotal', _rupees(bill.subtotalPaise), bold: true),
            for (final e in creditExpenses)
              _kv('${e.name} credit', '- ${_rupees(e.amountPaise)}'),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400, thickness: 1.2),
            pw.SizedBox(height: 4),
            _kv(
              'Total Due',
              _rupees(bill.amountDuePaise),
              bold: true,
              big: true,
            ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generated on ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
    ),
  );

  return doc.save();
}

pw.Widget _kv(String label, String value, {bool bold = false, bool big = false}) {
  final style = pw.TextStyle(
    fontSize: big ? 15 : 12,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    ),
  );
}
