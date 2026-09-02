import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/personal_expense.dart';
import '../../providers/personal_expense_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';
import 'add_personal_expense_screen.dart';

/// One fixed color per [personalExpenseCategories] entry, in that same
/// order, so a category always renders the same pie-chart color no matter
/// how the map iterates.
const _categoryColors = <String, Color>{
  'food': AppTheme.sage,
  'transport': AppTheme.primary,
  'shopping': AppTheme.rose,
  'bills': AppTheme.amber,
  'health': Color(0xFF2563EB),
  'entertainment': Color(0xFF7C3AED),
  'other': AppTheme.textLight,
};

/// A resident's own spending — entirely separate from the building's
/// shared finances. Reached from the Profile screen, not the bottom nav,
/// since it's a personal side-feature rather than a top-level tab.
class PersonalExpensesScreen extends StatelessWidget {
  const PersonalExpensesScreen({super.key});

  String _categoryLabel(String category) {
    final capitalized = category.isEmpty
        ? category
        : category[0].toUpperCase() + category.substring(1);
    return AppLocalizations.t('category$capitalized');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PersonalExpenseProvider>();
    final expenses = provider.expenses;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('personalExpenses')),
              Expanded(
                child: expenses.isEmpty
                    ? EmptyState(
                        icon: Icons.account_balance_wallet_rounded,
                        title: AppLocalizations.t('noPersonalExpensesTitle'),
                        subtitle: AppLocalizations.t('noPersonalExpensesSub'),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          AppCard(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.t('totalSpentLabel'),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppTheme.textLight,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        formatPaise(provider.totalPaise),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (provider.totalsByCategory.length > 1)
                            _CategoryPieChart(
                              totalsByCategory: provider.totalsByCategory,
                              totalPaise: provider.totalPaise,
                              categoryLabel: _categoryLabel,
                            ),
                          for (final expense in expenses)
                            _ExpenseRow(
                              expense: expense,
                              categoryLabel: _categoryLabel(expense.category),
                              onDelete: () => context
                                  .read<PersonalExpenseProvider>()
                                  .deleteExpense(expense.id),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddPersonalExpenseScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(AppLocalizations.t('addPersonalExpense')),
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

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({
    required this.totalsByCategory,
    required this.totalPaise,
    required this.categoryLabel,
  });

  final Map<String, int> totalsByCategory;
  final int totalPaise;
  final String Function(String category) categoryLabel;

  @override
  Widget build(BuildContext context) {
    final entries = totalsByCategory.entries.toList();

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t('spendingByCategoryLabel'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                sections: [
                  for (final entry in entries)
                    PieChartSectionData(
                      value: entry.value.toDouble(),
                      color:
                          _categoryColors[entry.key] ?? AppTheme.textLight,
                      radius: 34,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _categoryColors[entry.key] ?? AppTheme.textLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      categoryLabel(entry.key),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                  Text(
                    '${(entry.value / totalPaise * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatPaise(entry.value),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
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

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.categoryLabel,
    required this.onDelete,
  });

  final PersonalExpense expense;
  final String categoryLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppTheme.roseBg,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.rose),
      ),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$categoryLabel · ${DateFormat('MMM d, yyyy').format(expense.date)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatPaise(expense.amountPaise),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
