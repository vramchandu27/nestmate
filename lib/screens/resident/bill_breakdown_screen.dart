import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/screen_header.dart';
import 'pay_now_screen.dart';

/// Detailed bill calculation view for the logged-in resident's flat,
/// sourced entirely from [SocietyProvider] — meter reading, water charge,
/// common share, and any offset credits this flat is owed.
class BillBreakdownScreen extends StatelessWidget {
  const BillBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flatNumber = context.watch<AppProvider>().flatNumber ?? '';
    final society = context.watch<SocietyProvider>();
    final month = society.currentMonth;
    final bill = society.billForResident(flatNumber);
    final reading = month.readingFor(flatNumber);
    final flat = society.flatByNumber(flatNumber);
    final creditExpenses = month.expenses
        .where((e) => e.paidByFlatNumber == flatNumber)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('seeHowItsCalculated')),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                month.label,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalizations.t('flat')} $flatNumber',
                                style: const TextStyle(
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              AppLocalizations.t('dueBy'),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (!(flat?.tankerExempt ?? false)) ...[
                        Text(
                          '💧 ${AppLocalizations.t('waterMeter')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _ReadingCol(
                                    label: AppLocalizations.t('startReading'),
                                    value: '${reading?.initialLitres ?? 0}',
                                  ),
                                  const Text(
                                    '→',
                                    style: TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 22,
                                    ),
                                  ),
                                  _ReadingCol(
                                    label: AppLocalizations.t('endReading'),
                                    value: '${reading?.finalLitres ?? 0}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(height: 1, color: AppTheme.borderColor),
                              const SizedBox(height: 16),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      '${reading?.usageLitres ?? 0} L',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppLocalizations.t('yourUsageThisMonth'),
                                      style: const TextStyle(
                                        color: AppTheme.textMedium,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.t(
                                            'featureComingSoon',
                                          ),
                                        ),
                                      ),
                                    ),
                                child: Text(
                                  '📷 ${AppLocalizations.t('viewMeterPhoto')}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        AppLocalizations.t('billBreakdown'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        child: Column(
                          children: [
                            if (bill.openingBalancePaise != 0)
                              _Row(
                                label: AppLocalizations.t('openingBalance'),
                                value: bill.openingBalancePaise > 0
                                    ? formatPaise(bill.openingBalancePaise)
                                    : formatPaiseSigned(
                                        bill.openingBalancePaise,
                                      ),
                                valueColor: bill.openingBalancePaise < 0
                                    ? AppTheme.success
                                    : null,
                              ),
                            if (!(flat?.tankerExempt ?? false))
                              _Row(
                                label: AppLocalizations.t('waterTankerShare'),
                                sub: '(${reading?.usageLitres ?? 0} L)',
                                value: formatPaise(bill.waterChargePaise),
                              ),
                            _Row(
                              label: AppLocalizations.t('commonMaintenance'),
                              value: formatPaise(bill.commonSharePaise),
                            ),
                            _Row(
                              label: AppLocalizations.t('subtotal'),
                              value: formatPaise(bill.subtotalPaise),
                              bold: true,
                            ),
                            for (final e in creditExpenses)
                              _Row(
                                label:
                                    '${e.name} ${AppLocalizations.t('credits')}',
                                value: formatPaiseSigned(-e.amountPaise),
                                valueColor: AppTheme.success,
                                bold: true,
                              ),
                            _Row(
                              label: AppLocalizations.t('total'),
                              value: formatPaise(bill.amountDuePaise),
                              bold: true,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.t('featureComingSoon'),
                                      ),
                                    ),
                                  ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                                minimumSize: const Size(0, 52),
                                textStyle: const TextStyle(fontSize: 13.5),
                              ),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: Text(
                                AppLocalizations.t('downloadStatement'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PayNowScreen(),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                                minimumSize: const Size(0, 52),
                                textStyle: const TextStyle(fontSize: 13.5),
                              ),
                              icon: const Icon(Icons.payment_rounded, size: 18),
                              label: Text(
                                AppLocalizations.t('pay'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
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

class _ReadingCol extends StatelessWidget {
  const _ReadingCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.sub,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.isTotal = false,
  });

  final String label;
  final String? sub;
  final String value;
  final Color? valueColor;
  final bool bold;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    fontSize: isTotal ? 16 : 14,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ??
                  (isTotal ? AppTheme.primary : AppTheme.textDark),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
