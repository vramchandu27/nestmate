import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
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
/// shared finances. Its own bottom-nav tab (not nested under Profile),
/// since it has nothing to do with the building and residents should be
/// able to land on it directly.
class PersonalExpensesScreen extends StatefulWidget {
  const PersonalExpensesScreen({super.key, this.showLogout = false});

  /// True only when this screen is the entire app for the signed-in user
  /// (the standalone `/personal-shell` route for the personal-tracker-only
  /// role) — as a resident bottom-nav tab, logout already lives on the
  /// Profile tab.
  final bool showLogout;

  @override
  State<PersonalExpensesScreen> createState() =>
      _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState extends State<PersonalExpensesScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() {
      var newMonth = _month + delta;
      var newYear = _year;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      } else if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }
      _month = newMonth;
      _year = newYear;
    });
  }

  String _categoryLabel(String category) {
    final capitalized = category.isEmpty
        ? category
        : category[0].toUpperCase() + category.substring(1);
    return AppLocalizations.t('category$capitalized');
  }

  Future<void> _editSalary(
    BuildContext context,
    PersonalExpenseProvider provider,
  ) async {
    final ctrl = TextEditingController(
      text: provider.salaryPaise > 0 ? '${provider.salaryPaise ~/ 100}' : '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('setSalaryTitle')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: AppLocalizations.t('monthlySalaryLabel'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.t('saveBtn')),
          ),
        ],
      ),
    );
    if (save == true) {
      await provider.setSalary(parseRupeesToPaise(ctrl.text));
    }
  }

  Future<void> _editBudget(
    BuildContext context,
    PersonalExpenseProvider provider,
    String category,
  ) async {
    final existing = provider.budgetForCategory(_year, _month, category);
    final ctrl = TextEditingController(
      text: existing != null && existing > 0 ? '${existing ~/ 100}' : '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${_categoryLabel(category)} · '
          '${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}',
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: AppLocalizations.t('monthlyBudgetHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.t('saveBtn')),
          ),
        ],
      ),
    );
    if (save == true) {
      await provider.setCategoryBudget(
        _year,
        _month,
        category,
        parseRupeesToPaise(ctrl.text),
      );
    }
  }

  void _openEditExpense(BuildContext context, PersonalExpense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPersonalExpenseScreen(existing: expense),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PersonalExpenseProvider>();
    final expenses = provider.expensesForMonth(_year, _month);
    final totalPaise = provider.totalPaiseForMonth(_year, _month);
    final totalsByCategory = provider.totalsByCategoryForMonth(_year, _month);
    final remainingPaise = provider.remainingPaiseForMonth(_year, _month);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: AppLocalizations.t('personalExpenses'),
                showBackButton: false,
                trailing: widget.showLogout
                    ? GestureDetector(
                        onTap: () => performLogout(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.shadowSm,
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.textMedium,
                            size: 19,
                          ),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _MonthSelector(
                      year: _year,
                      month: _month,
                      canGoForward: !_isCurrentMonth,
                      onPrevious: () => _shiftMonth(-1),
                      onNext: () => _shiftMonth(1),
                    ),
                    const SizedBox(height: 12),
                    _SalaryCard(
                      salaryPaise: provider.salaryPaise,
                      remainingPaise: remainingPaise,
                      onEditSalary: () => _editSalary(context, provider),
                    ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  formatPaise(totalPaise),
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
                    if (totalsByCategory.length > 1)
                      _CategoryPieChart(
                        totalsByCategory: totalsByCategory,
                        totalPaise: totalPaise,
                        categoryLabel: _categoryLabel,
                      ),
                    _BudgetsSection(
                      budgets: provider.effectiveBudgetsForMonth(_year, _month),
                      spentByCategory: totalsByCategory,
                      categoryLabel: _categoryLabel,
                      onTapCategory: (category) =>
                          _editBudget(context, provider, category),
                    ),
                    if (expenses.isEmpty)
                      EmptyState(
                        icon: Icons.account_balance_wallet_rounded,
                        title: AppLocalizations.t('noPersonalExpensesTitle'),
                        subtitle: AppLocalizations.t('noPersonalExpensesSub'),
                      )
                    else
                      for (final expense in expenses)
                        _ExpenseRow(
                          expense: expense,
                          categoryLabel: _categoryLabel(expense.category),
                          onTap: () => _openEditExpense(context, expense),
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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.year,
    required this.month,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final int month;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MonthArrowButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        SizedBox(
          width: 160,
          child: Text(
            DateFormat('MMMM yyyy').format(DateTime(year, month)),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppTheme.textDark,
            ),
          ),
        ),
        _MonthArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: canGoForward ? onNext : null,
        ),
      ],
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.textDark : AppTheme.textLight,
        ),
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({
    required this.salaryPaise,
    required this.remainingPaise,
    required this.onEditSalary,
  });

  final int salaryPaise;
  final int remainingPaise;
  final VoidCallback onEditSalary;

  @override
  Widget build(BuildContext context) {
    final hasSalary = salaryPaise > 0;
    final isOverspent = remainingPaise < 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t('monthlySalaryLabel'),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: onEditSalary,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.t(
                        hasSalary ? 'editBtn' : 'addSalaryBtn',
                      ),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasSalary ? formatPaise(salaryPaise) : '—',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          if (hasSalary) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.t(
                    isOverspent ? 'overspentLabel' : 'remainingBalanceLabel',
                  ),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMedium,
                  ),
                ),
                Text(
                  formatPaiseSigned(remainingPaise),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isOverspent ? AppTheme.rose : AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetsSection extends StatelessWidget {
  const _BudgetsSection({
    required this.budgets,
    required this.spentByCategory,
    required this.categoryLabel,
    required this.onTapCategory,
  });

  final Map<String, int> budgets;
  final Map<String, int> spentByCategory;
  final String Function(String category) categoryLabel;
  final void Function(String category) onTapCategory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t('monthlyBudgetsLabel'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.t('monthlyBudgetsSub'),
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textLight),
          ),
          const SizedBox(height: 10),
          for (final category in personalExpenseCategories)
            _BudgetRow(
              label: categoryLabel(category),
              limitPaise: budgets[category],
              spentPaise: spentByCategory[category] ?? 0,
              onTap: () => onTapCategory(category),
            ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.label,
    required this.limitPaise,
    required this.spentPaise,
    required this.onTap,
  });

  final String label;
  final int? limitPaise;
  final int spentPaise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLimit = limitPaise != null && limitPaise! > 0;
    final progress = hasLimit ? (spentPaise / limitPaise!).clamp(0.0, 1.0) : 0.0;
    final isOver = hasLimit && spentPaise > limitPaise!;
    final barColor = isOver
        ? AppTheme.rose
        : (progress > 0.8 ? AppTheme.amber : AppTheme.success);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMedium,
                  ),
                ),
                hasLimit
                    ? Text(
                        '${formatPaise(spentPaise)} / ${formatPaise(limitPaise!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isOver ? AppTheme.rose : AppTheme.textDark,
                        ),
                      )
                    : Text(
                        AppLocalizations.t('setBudgetBtn'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.borderColor,
                  color: barColor,
                ),
              ),
            ],
          ],
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
    required this.onTap,
    required this.onDelete,
  });

  final PersonalExpense expense;
  final String categoryLabel;
  final VoidCallback onTap;
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
        onTap: onTap,
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
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textLight,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
