import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';

/// Read-only view of this month's common-pool expenses and advances, with
/// dates — so a resident can see exactly what's behind their bill instead
/// of only finding out via the group WhatsApp message. Residents can only
/// ever read this data (see firestore.rules); adding/editing stays
/// admin-only on the Expenses screen.
class BuildingExpensesScreen extends StatelessWidget {
  const BuildingExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final month = society.currentMonth;
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('buildingExpensesTitle')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  month.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppLocalizations.t('commonPoolTotalLabel'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatPaise(month.commonPoolPaise),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.t('reserveFundBalance'),
                              style: const TextStyle(
                                color: AppTheme.textMedium,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            formatPaise(society.building.reserveFundPaise),
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (month.expenses.isEmpty && month.advances.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: AppLocalizations.t('noExpensesYetTitle'),
                        subtitle: AppLocalizations.t('noExpensesYetSub'),
                      )
                    else ...[
                      for (final e in month.expenses)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatPaise(e.amountPaise),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${e.category} · ${dateFormat.format(e.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                ),
                              ),
                              if (e.fundedByReserve) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amber.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    AppLocalizations.t('paidFromReserveBadge'),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8A6D00),
                                    ),
                                  ),
                                ),
                              ],
                              if (e.paidByFlatNumber != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentTeal,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${AppLocalizations.t('frontedBy')} ${e.paidByFlatNumber}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF227A52),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      for (final a in month.advances)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 9),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 1.2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.reason,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatPaise(a.amountPaise),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalizations.t('advanceGivenTo')} ${a.givenToName} · ${dateFormat.format(a.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
