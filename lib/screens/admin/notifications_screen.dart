import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/bill.dart';
import '../../models/issue_report.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/issue_details_sheet.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/section_header.dart';
import 'confirm_payments_screen.dart';

/// Unifies everything the dashboard bell's badge counts — pending payment
/// confirmations and open issues — into one list, so tapping a
/// notification always lands somewhere that actually explains it (the
/// bell used to always open Issues, even when the badge was counting
/// payments awaiting confirmation).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final pendingPayments = society.currentMonth.bills
        .where((b) => b.status == BillStatus.screenshotUploaded)
        .toList();
    final openIssues = society.issues
        .where((i) => i.status != IssueStatus.resolved)
        .toList();
    final isEmpty = pendingPayments.isEmpty && openIssues.isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('notifications')),
              Expanded(
                child: isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: AppLocalizations.t('noNotificationsTitle'),
                        subtitle: AppLocalizations.t('noNotificationsSub'),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (pendingPayments.isNotEmpty) ...[
                            SectionHeader(
                              AppLocalizations.t('awaitingConfirmationLabel'),
                            ),
                            const SizedBox(height: 10),
                            for (final bill in pendingPayments)
                              AppCard(
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ConfirmPaymentsScreen(),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    IconBadge.icon(
                                      Icons.hourglass_bottom_rounded,
                                      background: AppTheme.amberBg,
                                      color: AppTheme.amber,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${AppLocalizations.t('flat')} ${bill.flatNumber} · ${society.flatByNumber(bill.flatNumber)?.residentName ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatPaise(bill.amountDuePaise),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.textLight,
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],
                          if (openIssues.isNotEmpty) ...[
                            SectionHeader(
                              AppLocalizations.t('openIssuesLabel'),
                            ),
                            const SizedBox(height: 10),
                            for (final issue in openIssues)
                              AppCard(
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                onTap: () => showIssueDetails(
                                  context,
                                  issue: issue,
                                  showFlatNumber: true,
                                  onResolve: () => context
                                      .read<SocietyProvider>()
                                      .resolveIssue(issue.id),
                                ),
                                child: Row(
                                  children: [
                                    IconBadge.icon(
                                      Icons.report_problem_rounded,
                                      background: AppTheme.roseBg,
                                      color: AppTheme.rose,
                                    ),
                                    const SizedBox(width: 12),
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
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.textLight,
                                    ),
                                  ],
                                ),
                              ),
                          ],
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
