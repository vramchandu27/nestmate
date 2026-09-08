import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/expense.dart';
import '../../providers/society_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/photo_picker_field.dart';
import '../../widgets/screen_header.dart';

/// Add (or edit) a common-pool expense: what it was for, how much, how
/// it's split, and — the key offset mechanic — whether a resident fronted
/// it, which credits that flat's own bill for the full amount.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.existing});

  /// Non-null when reopening this form to edit an already-recorded
  /// expense, rather than creating a new one.
  final Expense? existing;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _otherCategoryCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _category;
  ExpenseSplitRule _splitRule = ExpenseSplitRule.allFlats;
  final Set<String> _specificFlats = {};
  bool _fronted = false;
  String? _frontingFlat;
  File? _receiptFile;
  String? _existingReceiptUrl;
  bool _isLoading = false;
  bool _submitted = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;

    final categories = context.read<SocietyProvider>().building.commonCategories;
    final isCustomCategory = !categories.contains(existing.category);

    _nameCtrl.text = existing.name;
    _amountCtrl.text = (existing.amountPaise ~/ 100).toString();
    _category = isCustomCategory ? 'Other' : existing.category;
    if (isCustomCategory) _otherCategoryCtrl.text = existing.category;
    _splitRule = existing.splitRule;
    _specificFlats.addAll(existing.specificFlatNumbers);
    _fronted = existing.paidByFlatNumber != null;
    _frontingFlat = existing.paidByFlatNumber;
    _existingReceiptUrl = existing.receiptPhotoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _otherCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(SocietyProvider society) async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final categories = society.building.commonCategories;
    final category = _category == 'Other'
        ? _otherCategoryCtrl.text.trim()
        : (_category ?? categories.first);
    final expenseId =
        widget.existing?.id ?? 'exp${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _isLoading = true);
    var receiptFailed = false;
    await withLoadingOverlay(context, () async {
      String? receiptUrl = _existingReceiptUrl;
      final receipt = _receiptFile;
      if (receipt != null) {
        // A receipt is supplementary — don't block recording the expense
        // itself just because the photo upload failed.
        try {
          receiptUrl = await StorageService().uploadPhoto(
            basePath:
                'buildings/main/months/${society.currentMonth.id}/expenses/$expenseId',
            file: receipt,
          );
        } catch (_) {
          receiptFailed = true;
        }
      }
      final expense = Expense(
        id: expenseId,
        name: _nameCtrl.text.trim(),
        category: category,
        amountPaise: parseRupeesToPaise(_amountCtrl.text),
        splitRule: _splitRule,
        specificFlatNumbers: _specificFlats.toList(),
        paidByFlatNumber: _fronted ? _frontingFlat : null,
        receiptPhotoUrl: receiptUrl,
        createdAt: widget.existing?.createdAt,
      );
      if (_isEditing) {
        await society.updateExpense(expense);
      } else {
        await society.addExpense(expense);
      }
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (receiptFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('errorOccurred')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _confirmDelete(SocietyProvider society) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('deleteExpenseTitle')),
        content: Text(AppLocalizations.t('deleteExpenseConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    await withLoadingOverlay(context, () async {
      await society.deleteExpense(widget.existing!.id);
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final flats = society.flats;
    final categories = society.building.commonCategories;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: AppLocalizations.t(
                  _isEditing ? 'editExpense' : 'addExpense',
                ),
                trailing: _isEditing
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.error,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => _confirmDelete(society),
                      )
                    : null,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
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
                      DropdownButtonFormField<String>(
                        initialValue: _category ?? categories.first,
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _category = v),
                      ),
                      if (_category == 'Other') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otherCategoryCtrl,
                          enabled: !_isLoading,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.t(
                              'specifyCategoryHint',
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? AppLocalizations.t('fieldRequired')
                              : null,
                        ),
                      ],
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
                      const SizedBox(height: 18),
                      Text(
                        AppLocalizations.t('splitAcross'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RadioTile(
                        label: AppLocalizations.t('allFlatsOption'),
                        selected: _splitRule == ExpenseSplitRule.allFlats,
                        onTap: () => setState(
                          () => _splitRule = ExpenseSplitRule.allFlats,
                        ),
                      ),
                      _RadioTile(
                        label: AppLocalizations.t('specificFlatsOption'),
                        selected: _splitRule == ExpenseSplitRule.specificFlats,
                        onTap: () => setState(
                          () => _splitRule = ExpenseSplitRule.specificFlats,
                        ),
                      ),
                      if (_splitRule == ExpenseSplitRule.specificFlats)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            top: 4,
                            bottom: 4,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final f in flats)
                                FilterChip(
                                  label: Text(f.flatNumber),
                                  selected: _specificFlats.contains(
                                    f.flatNumber,
                                  ),
                                  onSelected: (sel) => setState(() {
                                    if (sel) {
                                      _specificFlats.add(f.flatNumber);
                                    } else {
                                      _specificFlats.remove(f.flatNumber);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        AppLocalizations.t('whoPaidThis'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RadioTile(
                        label: AppLocalizations.t('paidToCollector'),
                        selected: !_fronted,
                        onTap: () => setState(() => _fronted = false),
                      ),
                      _RadioTile(
                        label: AppLocalizations.t('residentFrontedIt'),
                        selected: _fronted,
                        onTap: () => setState(() => _fronted = true),
                      ),
                      if (_fronted) ...[
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.t('whichFlatFronted'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _frontingFlat,
                          items: flats
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f.flatNumber,
                                  child: Text(
                                    '${f.flatNumber} · ${f.residentName}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _frontingFlat = v),
                          validator: (v) => v == null
                              ? AppLocalizations.t('fieldRequired')
                              : null,
                        ),
                      ],
                      const SizedBox(height: 18),
                      PhotoPickerField(
                        label: AppLocalizations.t('addReceiptOptional'),
                        file: _receiptFile,
                        existingUrl: _existingReceiptUrl,
                        height: 100,
                        onChanged: (f) => setState(() {
                          _receiptFile = f;
                          if (f == null) _existingReceiptUrl = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _save(society),
                        child: Text(
                          AppLocalizations.t(
                            _isEditing ? 'updateExpenseBtn' : 'saveExpenseBtn',
                          ),
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

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentBlue : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppTheme.primary : AppTheme.textLight,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: selected ? AppTheme.primary : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
