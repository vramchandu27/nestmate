import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/bill.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/photo_picker_field.dart';
import '../../widgets/screen_header.dart';

/// UPI-style payment screen: shows the collector's UPI ID (copy / "open
/// UPI app" simulated), a screenshot-upload drop zone (simulated), and a
/// pending-confirmation status line.
class PayNowScreen extends StatefulWidget {
  const PayNowScreen({super.key});

  @override
  State<PayNowScreen> createState() => _PayNowScreenState();
}

class _PayNowScreenState extends State<PayNowScreen> {
  File? _screenshotFile;
  bool _replacing = false;

  Future<void> _onScreenshotChanged(File? f, String flatNumber) async {
    setState(() => _screenshotFile = f);
    if (f == null) return;
    final society = context.read<SocietyProvider>();
    try {
      final url = await StorageService().uploadPhoto(
        basePath:
            'buildings/main/months/${society.currentMonth.id}/bills/$flatNumber',
        file: f,
      );
      await society.submitPaymentScreenshot(flatNumber, screenshotUrl: url);
    } catch (_) {
      if (!mounted) return;
      setState(() => _screenshotFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('errorOccurred')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatNumber = context.watch<AppProvider>().flatNumber ?? '';
    final society = context.watch<SocietyProvider>();
    final bill = society.billForResident(flatNumber);
    final upiId = society.building.upiId;
    // True once a screenshot exists for this bill — either picked this
    // session, or already on record from a previous visit to this
    // screen (bill.status survives even though the picked File doesn't).
    final hasSubmitted =
        _screenshotFile != null || bill.status != BillStatus.unpaid;
    final showStaticConfirmation =
        hasSubmitted && _screenshotFile == null && !_replacing;

    // Bills are generated once for every flat on the roster at that
    // moment — a flat added afterward has no bill doc yet even though
    // billsGenerated is already true for the month. Submitting a
    // screenshot for a bill that doesn't exist would try to *create* the
    // bill doc as a resident, which security rules never allow (bills are
    // admin-generated only) — gate on both instead of just the flag.
    if (!society.billsGenerated ||
        society.currentMonth.billFor(flatNumber) == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: AmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                ScreenHeader(title: AppLocalizations.t('pay')),
                Expanded(
                  child: EmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: AppLocalizations.t('billNotReadyTitle'),
                    subtitle: AppLocalizations.t('billNotReadySub'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title:
                    '${AppLocalizations.t('pay')} ${formatPaise(bill.amountDuePaise)}',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              AppLocalizations.t('payTo'),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              upiId,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: upiId),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.t(
                                              'successfullySaved',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(AppLocalizations.t('copyId')),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () async {
                                    final payeeName =
                                        society.building.collectorName.isNotEmpty
                                        ? society.building.collectorName
                                        : society.building.name;
                                    final amount =
                                        (bill.amountDuePaise / 100)
                                            .toStringAsFixed(2);
                                    // The upi:// scheme is a standard
                                    // Android intent every UPI app
                                    // registers for — launching it with
                                    // more than one such app installed
                                    // shows the OS's own app-chooser
                                    // (Google Pay, PhonePe, Paytm, …).
                                    final uri = Uri(
                                      scheme: 'upi',
                                      host: 'pay',
                                      queryParameters: {
                                        'pa': upiId,
                                        'pn': payeeName,
                                        'am': amount,
                                        'cu': 'INR',
                                        'tn':
                                            'Maintenance ${society.currentMonth.id}',
                                      },
                                    );
                                    final launched = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!launched && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.t(
                                              'noUpiAppFound',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(AppLocalizations.t('openUpiApp')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppLocalizations.t('afterPayUploadScreenshot'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMedium,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      showStaticConfirmation
                          // Already submitted in a previous visit — there's
                          // no picked File to preview (nothing persists
                          // across sessions), so show a static confirmation
                          // instead of the interactive picker's empty state.
                          ? Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(26),
                                  decoration: BoxDecoration(
                                    color: AppTheme.sageBg,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 32,
                                        color: AppTheme.success,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppLocalizations.t(
                                          'screenshotUploaded',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Once the admin confirms the payment it's
                                // settled — no more replacing the screenshot
                                // after that.
                                if (bill.status != BillStatus.confirmed) ...[
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _replacing = true),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      AppLocalizations.t(
                                        'replaceScreenshotBtn',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : PhotoPickerField(
                              label: AppLocalizations.t('uploadScreenshot'),
                              file: _screenshotFile,
                              height: 140,
                              onChanged: (f) =>
                                  _onScreenshotChanged(f, flatNumber),
                            ),
                      const SizedBox(height: 18),
                      Text(
                        hasSubmitted
                            ? AppLocalizations.t('paymentConfirmed')
                            : AppLocalizations.t('notPaidYet'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
