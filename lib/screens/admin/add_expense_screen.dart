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
  final _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _category;
  ExpenseSplitRule _splitRule = ExpenseSplitRule.allFlats;
  final Set<String> _specificFlats = {};
  bool _fronted = false;
  String? _frontingFlat;
  bool _fundedByReserve = false;
  File? _receiptFile;
  String? _existingReceiptUrl;
  bool _isLoading = false;
  bool _submitted = false;
  String? _reserveError;

  /// The day the money went out. Defaults to today, which is right for the
  /// common case of recording an expense as it happens, but editable for
  /// the equally common one of catching up on a bill paid last week.
  DateTime _spentOn = DateTime.now();

  bool get _isEditing => widget.existing != null;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatSpentOn(DateTime d) =>
      '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  /// Appends this edit to the expense's history, or leaves it untouched.
  ///
  /// Only the two figures a resident is paying against — the name and the
  /// amount — count as a change worth recording. Fixing a typo in the
  /// category or swapping a receipt photo doesn't alter what anyone owes,
  /// and logging those would bury the changes that do matter.
  List<ExpenseChange> _changeHistoryFor({
    required Expense? previous,
    required String newName,
    required int newAmountPaise,
  }) {
    if (previous == null) return const [];
    final changed =
        previous.name != newName || previous.amountPaise != newAmountPaise;
    if (!changed) return previous.changes;
    return [
      ...previous.changes,
      ExpenseChange(
        changedAt: DateTime.now(),
        reason: _reasonCtrl.text.trim(),
        previousName: previous.name,
        previousAmountPaise: previous.amountPaise,
      ),
    ];
  }

  /// Whether the admin has altered a figure residents are paying against,
  /// which is what makes the reason field appear and become required.
  bool get _needsReason {
    final previous = widget.existing;
    if (previous == null) return false;
    return previous.name != _nameCtrl.text.trim() ||
        previous.amountPaise != parseRupeesToPaise(_amountCtrl.text);
  }

  /// Says plainly that there is nothing in the reserve to pay from.
  ///
  /// The refusal used to be an inline message on the form, which is easy
  /// to miss — the expense silently stayed billed to residents, and the
  /// admin was left wondering why "Pay from Reserve Fund" never stuck.
  Future<void> _showEmptyReserveDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('emptyReserveTitle')),
        content: Text(AppLocalizations.t('emptyReserveBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('ok')),
          ),
        ],
      ),
    );
  }

  /// Shown when the reserve has money but not enough for this expense —
  /// only reachable at save time, since the amount can change after the
  /// funding option is chosen.
  Future<void> _showInsufficientReserveDialog(int balancePaise) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('insufficientReserveTitle')),
        content: Text(
          '${AppLocalizations.t('reserveFundBalance')}: ${formatPaise(balancePaise)}\n\n'
          '${AppLocalizations.t('insufficientReserveError')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSpentOn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentOn,
      // A society records what it has already spent, so a future date is
      // almost always a typo; two years back covers correcting old books.
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _spentOn = picked);
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;

    final categories = context.read<SocietyProvider>().building.commonCategories;
    final isCustomCategory = !categories.contains(existing.category);

    _nameCtrl.text = existing.name;
    _amountCtrl.text = (existing.amountPaise ~/ 100).toString();
    _spentOn = existing.spentOn;
    _category = isCustomCategory ? 'Other' : existing.category;
    if (isCustomCategory) _otherCategoryCtrl.text = existing.category;
    _splitRule = existing.splitRule;
    _specificFlats.addAll(existing.specificFlatNumbers);
    _fronted = existing.paidByFlatNumber != null;
    _frontingFlat = existing.paidByFlatNumber;
    _fundedByReserve = existing.fundedByReserve;
    _existingReceiptUrl = existing.receiptPhotoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _otherCategoryCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(SocietyProvider society) async {
    setState(() {
      _submitted = true;
      _reserveError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final categories = society.building.commonCategories;
    final category = _category == 'Other'
        ? _otherCategoryCtrl.text.trim()
        : (_category ?? categories.first);
    final expenseId =
        widget.existing?.id ?? 'exp${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _isLoading = true);
    var receiptFailed = false;
    var saved = true;
    await withLoadingOverlay(context, () async {
      String? receiptUrl = _existingReceiptUrl;
      final receipt = _receiptFile;
      if (receipt != null) {
        // A receipt is supplementary — don't block recording the expense
        // itself just because the photo upload failed.
        try {
          receiptUrl = await StorageService().uploadPhoto(
            basePath:
                'buildings/${society.buildingId}/months/${society.currentMonth.id}/expenses/$expenseId',
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
        paidByFlatNumber: _fundedByReserve
            ? null
            : (_fronted ? _frontingFlat : null),
        fundedByReserve: _fundedByReserve,
        receiptPhotoUrl: receiptUrl,
        createdAt: widget.existing?.createdAt,
        spentOn: _spentOn,
        changes: _changeHistoryFor(
          previous: widget.existing,
          newName: _nameCtrl.text.trim(),
          newAmountPaise: parseRupeesToPaise(_amountCtrl.text),
        ),
      );
      saved = _isEditing
          ? await society.updateExpense(expense)
          : await society.addExpense(expense);
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!saved) {
      // Insufficient reserve balance — SocietyProvider refused to write
      // anything, so stay on the form instead of popping as if it worked.
      setState(
        () => _reserveError = AppLocalizations.t('insufficientReserveError'),
      );
      // Also raised as a dialog: the inline message sits further down the
      // form than the button that triggered it, so on a long form it was
      // routinely missed and the save looked like it had simply done
      // nothing.
      await _showInsufficientReserveDialog(society.building.reserveFundPaise);
      return;
    }
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
                        // Rebuilds so the reason field appears the moment a
                        // recorded figure is altered, rather than only on save.
                        onChanged: (_) => setState(() {}),
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
                      // Only on an edit that actually moves a figure, so a
                      // brand-new expense is never asked to justify itself.
                      if (_needsReason) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t('changeReasonLabel'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF8A6D00),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.t('changeReasonHint'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textMedium,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _reasonCtrl,
                                enabled: !_isLoading,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                validator: (v) =>
                                    (v ?? '').trim().length >= 4
                                    ? null
                                    : AppLocalizations.t('changeReasonRequired'),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isLoading ? null : _pickSpentOn,
                        child: InputDecorator(
                          decoration: const InputDecoration(),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_rounded,
                                size: 18,
                                color: AppTheme.textMedium,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatSpentOn(_spentOn),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppTheme.textMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppLocalizations.t('howFundedLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RadioTile(
                        label: AppLocalizations.t('splitAcrossResidentsOption'),
                        selected: !_fundedByReserve,
                        onTap: () => setState(() => _fundedByReserve = false),
                      ),
                      _RadioTile(
                        label: AppLocalizations.t('payFromReserveOption'),
                        selected: _fundedByReserve,
                        // Checked the moment the option is picked, not left
                        // until save. An empty reserve can never pay for
                        // anything, and saying so here avoids filling in a
                        // whole form only to have it refused at the end.
                        onTap: () {
                          if (society.building.reserveFundPaise <= 0) {
                            _showEmptyReserveDialog();
                            return;
                          }
                          setState(() => _fundedByReserve = true);
                        },
                      ),
                      if (_fundedByReserve) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.t('reserveFundBalance')}: ${formatPaise(society.building.reserveFundPaise)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                      if (_reserveError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _reserveError!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                      if (!_fundedByReserve) ...[
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
                          selected:
                              _splitRule == ExpenseSplitRule.specificFlats,
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
