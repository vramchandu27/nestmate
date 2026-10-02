import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/work_item.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';

/// The admin's own private checklist — never shown to residents, unlike
/// issues, which residents raise.
class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  Future<void> _addItem(BuildContext context, SocietyProvider society) async {
    // A sheet rather than a dialog: there are now six fields, and a dialog
    // that tall fights the keyboard on a phone — the lower fields end up
    // hidden behind it with nothing to scroll.
    final result = await showModalBottomSheet<_NewWorkItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddWorkItemSheet(),
    );
    if (result == null) return;
    await society.addWorkItem(
      title: result.title,
      description: result.description,
      dueOn: result.dueOn,
      assignedTo: result.assignedTo,
      priority: result.priority,
      estimatedCostPaise: result.estimatedCostPaise,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SocietyProvider society,
    WorkItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('deleteWorkItemTitle')),
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
    if (confirmed == true) {
      await society.deleteWorkItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final items = society.workItems;
    // Overdue first, then urgent, then everything else, with finished
    // items sunk to the bottom — the order an admin scans for "what needs
    // me today".
    final sorted = [...items]
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        if (a.priority != b.priority) {
          return a.priority == WorkPriority.urgent ? -1 : 1;
        }
        final ad = a.dueOn, bd = b.dueOn;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: AppLocalizations.t('workListTitle'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
                  onPressed: () => _addItem(context, society),
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? EmptyState(
                        icon: Icons.checklist_rounded,
                        title: AppLocalizations.t('noWorkItemsTitle'),
                        subtitle: AppLocalizations.t('noWorkItemsSub'),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          for (final item in sorted)
                            _WorkItemCard(
                              item: item,
                              onToggle: () => society.toggleWorkItem(item.id),
                              onDelete: () =>
                                  _confirmDelete(context, society, item),
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

class _WorkItemCard extends StatelessWidget {
  const _WorkItemCard({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final WorkItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final struck = item.isDone ? TextDecoration.lineThrough : null;
    final dateFormat = DateFormat('d MMM');

    // Each fact gets its own small chip rather than a run-on line, so a
    // glance picks out what's overdue without reading anything.
    final chips = <Widget>[
      if (item.dueOn != null)
        _Chip(
          icon: Icons.event_rounded,
          label: dateFormat.format(item.dueOn!),
          color: item.isOverdue ? AppTheme.error : AppTheme.textLight,
        ),
      if (item.priority == WorkPriority.urgent && !item.isDone)
        _Chip(
          icon: Icons.priority_high_rounded,
          label: AppLocalizations.t('urgentLabel'),
          color: AppTheme.error,
        ),
      if (item.assignedTo.isNotEmpty)
        _Chip(icon: Icons.person_rounded, label: item.assignedTo),
      if (item.estimatedCostPaise > 0)
        _Chip(
          icon: Icons.currency_rupee_rounded,
          label: formatPaise(item.estimatedCostPaise).replaceFirst('₹', ''),
        ),
    ];

    return AppCard(
      margin: const EdgeInsets.only(bottom: 9),
      onTap: onToggle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: item.isDone ? AppTheme.success : AppTheme.textLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: item.isDone ? AppTheme.textLight : AppTheme.textDark,
                    decoration: struck,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textLight,
                      decoration: struck,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppTheme.textLight,
              size: 18,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the sheet hands back, so the screen itself holds no form state.
class _NewWorkItem {
  const _NewWorkItem({
    required this.title,
    required this.description,
    required this.dueOn,
    required this.assignedTo,
    required this.priority,
    required this.estimatedCostPaise,
  });

  final String title;
  final String description;
  final DateTime? dueOn;
  final String assignedTo;
  final WorkPriority priority;
  final int estimatedCostPaise;
}

class _AddWorkItemSheet extends StatefulWidget {
  const _AddWorkItemSheet();

  @override
  State<_AddWorkItemSheet> createState() => _AddWorkItemSheetState();
}

class _AddWorkItemSheetState extends State<_AddWorkItemSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _assignedCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime? _dueOn;
  WorkPriority _priority = WorkPriority.normal;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _assignedCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? now,
      // Work is scheduled ahead, so today is the floor; a year out covers
      // annual things like an AMC renewal.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null && mounted) setState(() => _dueOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');

    return Padding(
      // Lifts the sheet clear of the keyboard, which is the whole reason
      // this stopped being a dialog.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppLocalizations.t('addWorkItemTitle'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),

              _Label(AppLocalizations.t('workItemTaskLabel')),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: AppLocalizations.t('workItemTitleHint'),
                ),
              ),
              const SizedBox(height: 14),

              _Label(AppLocalizations.t('workItemDetailsLabel')),
              TextField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: AppLocalizations.t('workItemDescriptionHint'),
                ),
              ),
              const SizedBox(height: 14),

              _Label(AppLocalizations.t('workItemDueLabel')),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDue,
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
                          _dueOn == null
                              ? AppLocalizations.t('workItemNoDueDate')
                              : dateFormat.format(_dueOn!),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: _dueOn == null
                                ? AppTheme.textLight
                                : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (_dueOn != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueOn = null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 17,
                            color: AppTheme.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _Label(AppLocalizations.t('workItemAssignedLabel')),
              TextField(
                controller: _assignedCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: AppLocalizations.t('workItemAssignedHint'),
                ),
              ),
              const SizedBox(height: 14),

              _Label(AppLocalizations.t('workItemCostLabel')),
              TextField(
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: AppLocalizations.t('workItemCostHint'),
                ),
              ),
              const SizedBox(height: 16),

              _Label(AppLocalizations.t('workItemPriorityLabel')),
              Row(
                children: [
                  Expanded(
                    child: _PriorityChoice(
                      label: AppLocalizations.t('normalLabel'),
                      selected: _priority == WorkPriority.normal,
                      onTap: () =>
                          setState(() => _priority = WorkPriority.normal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PriorityChoice(
                      label: AppLocalizations.t('urgentLabel'),
                      selected: _priority == WorkPriority.urgent,
                      onTap: () =>
                          setState(() => _priority = WorkPriority.urgent),
                      accent: AppTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Enabled as soon as there is a task, and rebuilt on
                  // every keystroke — the old dialog checked this once at
                  // open time, so the button could never become enabled
                  // and no work item could be added at all.
                  onPressed: _titleCtrl.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          _NewWorkItem(
                            title: _titleCtrl.text.trim(),
                            description: _descCtrl.text.trim(),
                            dueOn: _dueOn,
                            assignedTo: _assignedCtrl.text.trim(),
                            priority: _priority,
                            estimatedCostPaise: parseRupeesToPaise(
                              _costCtrl.text,
                            ),
                          ),
                        ),
                  child: Text(AppLocalizations.t('addWorkItemBtn')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: AppTheme.textMedium,
        ),
      ),
    );
  }
}

class _PriorityChoice extends StatelessWidget {
  const _PriorityChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppTheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: selected ? c : AppTheme.textMedium,
          ),
        ),
      ),
    );
  }
}
