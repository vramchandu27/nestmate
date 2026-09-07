import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/bill.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/waving_hand.dart';
import 'bill_breakdown_screen.dart';
import 'pay_now_screen.dart';
import 'report_issue_screen.dart';

/// The "Building" tab content — the resident's home: bill hero card,
/// earlier months, and a way into issue reporting. Lives inside
/// [ResidentShellScreen]'s bottom-nav, so it has no Scaffold of its own.
class BuildingTabScreen extends StatelessWidget {
  const BuildingTabScreen({super.key, this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final society = context.watch<SocietyProvider>();
    final flatNumber = app.flatNumber ?? '';
    final flat = society.flatByNumber(flatNumber);
    final bill = society.billForResident(flatNumber);
    final month = society.currentMonth;
    final pastBills = society.pastBillsForFlat(flatNumber);
    final issues = society.issuesForFlat(flatNumber);

    final creditExpenses = month.expenses
        .where((e) => e.paidByFlatNumber == flatNumber)
        .toList();

    return SafeArea(
      child: Column(
        children: [
          _Header(
            name: app.userName ?? flat?.residentName ?? '',
            flatNumber: flatNumber,
            onTapAvatar: onOpenProfile,
            photoUrl: app.userPhotoUrl,
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BillHeroCard(
                    monthLabel: month.label,
                    bill: bill,
                    creditLabel: creditExpenses.isEmpty
                        ? null
                        : '${creditExpenses.first.name} ${AppLocalizations.t('credits')} ${formatPaiseSigned(-creditExpenses.fold(0, (s, e) => s + e.amountPaise))}',
                    onPay: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PayNowScreen()),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BillBreakdownScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: Text(AppLocalizations.t('seeHowItsCalculated')),
                  ),
                  const SizedBox(height: 8),
                  SectionHeader(AppLocalizations.t('earlierMonths')),
                  if (pastBills.isEmpty)
                    Text(
                      AppLocalizations.t('noEarlierMonthsYet'),
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 13,
                      ),
                    )
                  else
                    for (final b in pastBills)
                      _PastBillRow(monthId: b.monthId, bill: b),
                  const SizedBox(height: 12),
                  SectionHeader(AppLocalizations.t('myIssues')),
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            StatusPill(
                              label: issue.status.name == 'resolved'
                                  ? AppLocalizations.t('resolved')
                                  : AppLocalizations.t('inProgress'),
                              status: issue.status.name == 'resolved'
                                  ? PillStatus.resolved
                                  : PillStatus.inProgress,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportIssueScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.report_problem_rounded, size: 19),
                      label: Text(AppLocalizations.t('reportIssue')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.roseBg,
                        foregroundColor: AppTheme.rose,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.flatNumber,
    this.onTapAvatar,
    this.photoUrl,
  });

  final String name;
  final String flatNumber;
  final VoidCallback? onTapAvatar;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapAvatar,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primary,
              backgroundImage: photoUrl != null
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl != null
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.t('hi'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const WavingHand(),
                  ],
                ),
                Text(
                  '$name · ${AppLocalizations.t('flat')} $flatNumber',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              shape: BoxShape.circle,
              boxShadow: AppTheme.shadowSm,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillHeroCard extends StatelessWidget {
  const _BillHeroCard({
    required this.monthLabel,
    required this.bill,
    required this.creditLabel,
    required this.onPay,
  });

  final String monthLabel;
  final Bill bill;
  final String? creditLabel;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = bill.status == BillStatus.confirmed;
    final isAwaitingConfirmation = bill.status == BillStatus.screenshotUploaded;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  monthLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.primary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.t('paid'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isAwaitingConfirmation)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppLocalizations.t('awaitingConfirmationLabel'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  AppLocalizations.t('dueBy'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isConfirmed
                ? AppLocalizations.t('totalPaidSoFar')
                : AppLocalizations.t('amountDue'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            formatPaise(bill.amountDuePaise),
            style: AppTheme.displayStyle(
              context,
              size: 38,
              weight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (creditLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                creditLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
              ),
              child: Text(
                isConfirmed
                    ? AppLocalizations.t('paymentConfirmedByAdminLabel')
                    : isAwaitingConfirmation
                    ? AppLocalizations.t('awaitingConfirmationLabel')
                    : '${AppLocalizations.t('pay')} ${formatPaise(bill.amountDuePaise)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastBillRow extends StatelessWidget {
  const _PastBillRow({required this.monthId, required this.bill});

  final String monthId;
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              monthId,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Text(
            formatPaise(bill.amountDuePaise),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(
            label: bill.status == BillStatus.confirmed
                ? AppLocalizations.t('paid')
                : AppLocalizations.t('pending'),
            status: bill.status == BillStatus.confirmed
                ? PillStatus.paid
                : PillStatus.pending,
          ),
        ],
      ),
    );
  }
}
