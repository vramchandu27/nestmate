import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/expense.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/nav_list_tile.dart';
import '../../widgets/screen_header.dart';
import 'add_advance_screen.dart';
import 'add_expense_screen.dart';
import 'generate_bills_screen.dart';
import 'water_calculator_screen.dart';

/// This month's common-pool expenses & advances, plus the entry point
/// into the water calculator and bill generation.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final month = society.currentMonth;
    final flatNumbers = society.flats.map((f) => f.flatNumber).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Faded background photo — same treatment as the Welcome screen.
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                'assets/images/pexels-karola-g-5900226.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background.withValues(alpha: 0.45),
                    AppTheme.background.withValues(alpha: 0.72),
                    AppTheme.background.withValues(alpha: 0.45),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ScreenHeader(title: AppLocalizations.t('monthExpenses')),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Always visible — adding an advance shouldn't
                      // require adding an expense first just to reach it.
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.receipt_long_rounded,
                              label: AppLocalizations.t('addExpense'),
                              background: AppTheme.roseBg,
                              iconColor: AppTheme.rose,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddExpenseScreen(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.account_balance_wallet_rounded,
                              label: AppLocalizations.t('addAdvance'),
                              background: AppTheme.sageBg,
                              iconColor: AppTheme.sageDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddAdvanceScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      NavListTile(
                        icon: Icons.water_drop_rounded,
                        title: AppLocalizations.t('waterCalculation'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WaterCalculatorScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (month.expenses.isEmpty && month.advances.isEmpty)
                        EmptyState(
                          icon: Icons.request_quote_outlined,
                          title: AppLocalizations.t('emptyExpensesTitle'),
                          subtitle: AppLocalizations.t('emptyExpensesSub'),
                        )
                      else ...[
                        for (final e in month.expenses)
                              AppCard(
                                margin: const EdgeInsets.only(bottom: 9),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddExpenseScreen(existing: e),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppTheme.textLight,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.splitRule == ExpenseSplitRule.allFlats
                                          ? AppLocalizations.t('allFlatsOption')
                                          : '${e.specificFlatNumbers.length} flats',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                    if (e.paidByFlatNumber != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentTeal,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                      '${AppLocalizations.t('recoverFrom')} ${a.recoveries.map((r) => '${r.flatNumber} (${formatPaise(r.amountPaise)})').join(', ')}',
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
                if (flatNumbers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.textDark,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GenerateBillsScreen(),
                          ),
                        ),
                        child: Text(
                          '${AppLocalizations.t('generateBillsBtn')} →',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded, color: iconColor, size: 15),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
