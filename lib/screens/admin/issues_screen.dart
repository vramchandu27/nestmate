import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/issue_report.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/issue_details_sheet.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';

/// Admin view of every resident-submitted issue, with a way to mark one
/// resolved. (Previously there was no admin-facing way to see these at
/// all — residents could submit them, but they went nowhere.)
class IssuesScreen extends StatelessWidget {
  const IssuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final issues = society.issues;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('reportIssue')),
              Expanded(
                child: issues.isEmpty
                    ? EmptyState(
                        icon: Icons.task_alt_rounded,
                        title: AppLocalizations.t('resolved'),
                        subtitle: AppLocalizations.t(
                          'emptyExpensesSub',
                          defaultValue: '',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          for (final issue in issues)
                            GestureDetector(
                              onTap: () => showIssueDetails(
                                context,
                                issue: issue,
                                showFlatNumber: true,
                                onResolve: issue.status == IssueStatus.resolved
                                    ? null
                                    : () => context
                                          .read<SocietyProvider>()
                                          .resolveIssue(issue.id),
                              ),
                              child: AppCard(
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${AppLocalizations.t('flat')} ${issue.flatNumber} · ${issue.title}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${issue.type} · ${issue.location}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (issue.status == IssueStatus.resolved)
                                      StatusPill(
                                        label: AppLocalizations.t('resolved'),
                                        status: PillStatus.resolved,
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: () => context
                                            .read<SocietyProvider>()
                                            .resolveIssue(issue.id),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.t('confirmBtn'),
                                        ),
                                      ),
                                  ],
                                ),
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
