import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/personal_expense.dart';
import '../../providers/personal_expense_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';

/// Add (or edit) one personal expense — name, category, amount, date.
/// Deliberately simpler than the admin's AddExpenseScreen: no split rule,
/// no flats, no receipt photo, since none of that applies to a resident's
/// own spending.
class AddPersonalExpenseScreen extends StatefulWidget {
  const AddPersonalExpenseScreen({super.key, this.existing});

  /// Non-null when reopening this form to edit an already-recorded
  /// expense, rather than creating a new one.
  final PersonalExpense? existing;

  @override
  State<AddPersonalExpenseScreen> createState() =>
      _AddPersonalExpenseScreenState();
}

class _AddPersonalExpenseScreenState extends State<AddPersonalExpenseScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String _category;
  late DateTime _date;
  bool _isLoading = false;
  bool _submitted = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _category = existing?.category ?? personalExpenseCategories.first;
    _date = existing?.date ?? DateTime.now();
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _amountCtrl.text = (existing.amountPaise ~/ 100).toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _categoryLabel(String category) =>
      AppLocalizations.t('category${_capitalize(category)}');

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = context.read<PersonalExpenseProvider>();
    final expense = PersonalExpense(
      id: widget.existing?.id ?? 'pexp${DateTime.now().microsecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      category: _category,
      amountPaise: parseRupeesToPaise(_amountCtrl.text),
      date: _date,
    );
    await withLoadingOverlay(context, () {
      return _isEditing
          ? provider.updateExpense(expense)
          : provider.addExpense(expense);
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: AppLocalizations.t(
                  _isEditing ? 'editPersonalExpense' : 'addPersonalExpense',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submitted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.t('expenseNameLabel'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          enabled: !_isLoading,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? AppLocalizations.t('fieldRequired')
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.t('categoryLabel'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in personalExpenseCategories)
                              ChoiceChip(
                                label: Text(_categoryLabel(c)),
                                selected: _category == c,
                                onSelected: _isLoading
                                    ? null
                                    : (_) => setState(() => _category = c),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.t('amountLabel'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _amountCtrl,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          validator: (v) => parseRupeesToPaise(v ?? '') > 0
                              ? null
                              : AppLocalizations.t('enterValidAmount'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.t('expenseDateLabel'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _isLoading ? null : _pickDate,
                          child: Text(DateFormat('MMM d, yyyy').format(_date)),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            child: Text(AppLocalizations.t('save')),
                          ),
                        ),
                      ],
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
