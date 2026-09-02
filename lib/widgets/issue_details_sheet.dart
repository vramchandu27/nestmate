import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../config/localization/app_localizations.dart';
import '../models/issue_report.dart';
import 'full_screen_network_photo.dart';
import 'status_pill.dart';

/// Full detail view for a single reported issue, reached by tapping its
/// row in either the resident's "My issues" list or the admin's issues
/// list. [showFlatNumber] surfaces which flat filed it (admin view);
/// [onResolve] shows a "Mark resolved" action when provided and the
/// issue isn't resolved yet (admin view only).
void showIssueDetails(
  BuildContext context, {
  required IssueReport issue,
  bool showFlatNumber = false,
  VoidCallback? onResolve,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.t('issueDetails'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: issue.status == IssueStatus.resolved
                        ? AppLocalizations.t('resolved')
                        : AppLocalizations.t('inProgress'),
                    status: issue.status == IssueStatus.resolved
                        ? PillStatus.resolved
                        : PillStatus.inProgress,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                issue.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 14),
              _DetailRow(
                icon: Icons.category_rounded,
                label: AppLocalizations.t('issueType'),
                value: issue.type,
              ),
              _DetailRow(
                icon: Icons.place_rounded,
                label: AppLocalizations.t('whereLocation'),
                value: issue.location.isEmpty ? '—' : issue.location,
              ),
              if (showFlatNumber)
                _DetailRow(
                  icon: Icons.home_rounded,
                  label: AppLocalizations.t('flat'),
                  value: issue.flatNumber,
                ),
              _DetailRow(
                icon: Icons.event_rounded,
                label: AppLocalizations.t('submittedOn'),
                value: DateFormat(
                  'MMM d, yyyy · h:mm a',
                ).format(issue.createdAt),
              ),
              if (issue.photoUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FullScreenNetworkPhoto(url: issue.photoUrl!),
                      ),
                    ),
                    child: Image.network(
                      issue.photoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 160,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => SizedBox(
                        height: 160,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (issue.photoAdded)
                _DetailRow(
                  icon: Icons.photo_camera_rounded,
                  label: AppLocalizations.t('photoAttached'),
                  value: '✓',
                ),
              if (onResolve != null && issue.status != IssueStatus.resolved) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onResolve();
                    },
                    child: Text(AppLocalizations.t('confirmBtn')),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textLight),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
