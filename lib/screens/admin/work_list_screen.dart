import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/work_item.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';

/// The admin's own private checklist — a plain tick-off list, never shown
/// to residents. Deliberately not a multi-field form like Add Expense:
/// just a title, an optional note, and a checkbox.
class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  Future<void> _addItem(BuildContext context, SocietyProvider society) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('addWorkItemTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: AppLocalizations.t('workItemTitleHint'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.t('workItemDescriptionHint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: titleCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.t('addWorkItemBtn')),
          ),
        ],
      ),
    );
    if (added == true && titleCtrl.text.trim().isNotEmpty) {
      await society.addWorkItem(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
    }
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
    // Pending first, done items sink to the bottom of the list.
    final sorted = [...items]
      ..sort((a, b) => a.isDone == b.isDone ? 0 : (a.isDone ? 1 : -1));

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
                            AppCard(
                              margin: const EdgeInsets.only(bottom: 9),
                              onTap: () => society.toggleWorkItem(item.id),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: item.isDone
                                        ? AppTheme.success
                                        : AppTheme.textLight,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            color: item.isDone
                                                ? AppTheme.textLight
                                                : AppTheme.textDark,
                                            decoration: item.isDone
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (item.description.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: AppTheme.textLight,
                                              decoration: item.isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
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
                                    onPressed: () =>
                                        _confirmDelete(context, society, item),
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
