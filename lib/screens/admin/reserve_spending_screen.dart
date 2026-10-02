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
import 'add_expense_screen.dart';

/// What the reserve fund has been spent on this month — the expenses
/// marked "Pay from Reserve Fund" on the expense form.
///
/// Kept apart from the Expenses screen because these are not billed to
/// anyone: they come out of money already collected. Listing them together
/// meant a resident reading their breakdown saw items they were not in
/// fact paying for.
class ReserveSpendingScreen extends StatelessWidget {
  const ReserveSpendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final month = society.currentMonth;
    final spending = month.expenses.where((e) => e.fundedByReserve).toList();
    final totalPaise = spending.fold(0, (total, e) => total + e.amountPaise);
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('spentFromReserveLabel')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.t('reserveBalanceNow'),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '− ${formatPaise(totalPaise)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.rose,
                                ),
                              ),
                              Text(
                                formatPaise(
                                  society.building.reserveFundPaise,
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (spending.isEmpty)
                      EmptyState(
                        icon: Icons.savings_outlined,
                        title: AppLocalizations.t('noReserveSpendingTitle'),
                        subtitle: AppLocalizations.t('noReserveSpendingSub'),
                      )
                    else
                      for (final e in spending)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 9),
                          // Opens the same editor as the Expenses screen, so
                          // moving one back to being split across residents
                          // is reachable from here too.
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(existing: e),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${e.category} · ${dateFormat.format(e.spentOn)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '− ${formatPaise(e.amountPaise)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppTheme.rose,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textLight,
                                size: 18,
                              ),
                            ],
                          ),
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
