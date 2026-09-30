import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/expense.dart';
import '../../models/month_data.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/nav_list_tile.dart';
import '../../widgets/screen_header.dart';
import 'add_advance_screen.dart';
import 'add_expense_screen.dart';
import 'add_reserve_fund_screen.dart';
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
    // Reserve-funded expenses are paid from money already collected, not
    // billed to anyone this month, so they belong on the Reserve Fund
    // screen rather than mixed into the list that becomes the bill.
    final billedExpenses =
        month.expenses.where((e) => !e.fundedByReserve).toList();

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
                      _BillingMonthRow(society: society, month: month),
                      const SizedBox(height: 14),
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
                      NavListTile(
                        icon: Icons.savings_rounded,
                        title: AppLocalizations.t('reserveFundLabel'),
                        trailingText: formatPaise(
                          society.building.reserveFundPaise,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddReserveFundScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (billedExpenses.isEmpty && month.advances.isEmpty)
                        EmptyState(
                          icon: Icons.request_quote_outlined,
                          title: AppLocalizations.t('emptyExpensesTitle'),
                          subtitle: AppLocalizations.t('emptyExpensesSub'),
                        )
                      else ...[
                        for (final e in billedExpenses)
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
                                    if (e.fundedByReserve)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.amber.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.t(
                                            'paidFromReserveBadge',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF8A6D00),
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        '${e.splitRule == ExpenseSplitRule.allFlats ? AppLocalizations.t('allFlatsOption') : '${e.specificFlatNumbers.length} flats'}'
                                        ' · ${DateFormat('d MMM').format(e.spentOn)}',
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

/// Which month you're currently recording expenses/readings for — moved
/// here from the Generate Bills screen, since switching to a new month is
/// naturally something you do right when you start entering that month's
/// data, not something you'd go looking for on the "send bills" screen.
class _BillingMonthRow extends StatelessWidget {
  const _BillingMonthRow({required this.society, required this.month});

  final SocietyProvider society;
  final MonthData month;

  Future<void> _pickMonth(BuildContext context) async {
    final parts = month.id.split('-');
    var selectedYear = int.tryParse(parts[0]) ?? DateTime.now().year;
    var selectedMonth = int.tryParse(parts[1]) ?? DateTime.now().month;
    final years = [
      for (var y = selectedYear - 1; y <= selectedYear + 2; y++) y,
    ];

    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.t('selectBillingMonth')),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(SocietyProvider.monthNames[m - 1]),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedMonth = v ?? selectedMonth),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedYear = v ?? selectedYear),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (selectedYear, selectedMonth),
              ),
              child: Text(AppLocalizations.t('save')),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await society.setCurrentMonth(picked.$1, picked.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickMonth(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t('billingMonthLabel'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  Text(
                    month.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
