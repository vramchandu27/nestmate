import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../utils/group_summary.dart';
import '../../utils/money.dart';
import '../../utils/sms.dart';
import '../../utils/whatsapp.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_tile.dart';

/// Rolls up water + common + offsets + carry-forward into a per-flat bill
/// preview (spec §2e), then lets the admin send them to residents.
class GenerateBillsScreen extends StatelessWidget {
  const GenerateBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final month = society.currentMonth;
    final totalSpend = month.commonPoolPaise + month.water.totalTankerCostPaise;
    // Frozen amounts once generated, live drafts before — so a WhatsApp
    // message never quotes a number that can still drift.
    final drafts = society.flats
        .map((f) => society.billForResident(f.flatNumber))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('previewBills')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: formatPaise(totalSpend),
                            label: AppLocalizations.t('totalSpend'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: '${drafts.length}',
                            label: AppLocalizations.t('billsReadyCount'),
                            valueColor: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _GroupSummaryCard(society: society),
                    const SizedBox(height: 16),
                    for (final bill in drafts)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocalizations.t('flat')} ${bill.flatNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  if (bill.offsetCreditsPaise > 0)
                                    Text(
                                      formatPaiseSigned(
                                        -bill.offsetCreditsPaise,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else if (bill.openingBalancePaise > 0)
                                    Text(
                                      '+${formatPaise(bill.openingBalancePaise)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else if (bill.openingBalancePaise < 0)
                                    Text(
                                      formatPaiseSigned(
                                        bill.openingBalancePaise,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              formatPaise(bill.amountDuePaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.chat_rounded,
                                color: AppTheme.success,
                              ),
                              tooltip: AppLocalizations.t('sendViaWhatsApp'),
                              onPressed: !month.generated
                                  ? null
                                  : () async {
                                      final flat = society.flatByNumber(
                                        bill.flatNumber,
                                      );
                                      final ok = await sendBillViaWhatsApp(
                                        phone: flat?.phone ?? '',
                                        building: society.building,
                                        monthLabel: month.label,
                                        flatNumber: bill.flatNumber,
                                        residentName: flat?.residentName ?? '',
                                        bill: bill,
                                      );
                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppLocalizations.t(
                                                'whatsAppOpenFailed',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.sms_rounded,
                                color: AppTheme.primary,
                              ),
                              tooltip: AppLocalizations.t('sendViaSms'),
                              onPressed: !month.generated
                                  ? null
                                  : () async {
                                      final flat = society.flatByNumber(
                                        bill.flatNumber,
                                      );
                                      final ok = await sendBillViaSms(
                                        phone: flat?.phone ?? '',
                                        building: society.building,
                                        monthLabel: month.label,
                                        flatNumber: bill.flatNumber,
                                        residentName: flat?.residentName ?? '',
                                        bill: bill,
                                      );
                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppLocalizations.t(
                                                'smsOpenFailed',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // Stays tappable even after the first generation —
                    // generateBills() is deliberately safe to re-run (see
                    // SocietyProvider.generateBills): it only adds bills
                    // for flats that don't have one yet and refreshes
                    // amounts, without touching an in-progress or
                    // confirmed payment. Needed for e.g. a flat added
                    // after this month's bills were first generated.
                    onPressed: () async {
                      await withLoadingOverlay(
                        context,
                        () => context.read<SocietyProvider>().generateBills(),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.t('successfullySaved'),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      month.generated
                          ? AppLocalizations.t('refreshBillsBtn')
                          : AppLocalizations.t('sendToResidents'),
                    ),
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

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({required this.society});

  final SocietyProvider society;

  String _message() => buildGroupSummaryMessage(
    building: society.building,
    month: society.currentMonth,
    flats: society.flats,
    exemptFlatNumbers: society.exemptFlatNumbers,
    billFor: society.billForResident,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.sageDark.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.sage, AppTheme.sageDark],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -24,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t('shareGroupSummary'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.t('shareGroupSummarySub'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await sendTextViaWhatsApp(_message());
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.t('whatsAppOpenFailed'),
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.sageDark,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: Text(
                              AppLocalizations.t('sendViaWhatsApp'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _message()),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.t('copiedToClipboard'),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

