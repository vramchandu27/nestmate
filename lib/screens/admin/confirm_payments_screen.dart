import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/bill.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/full_screen_network_photo.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/screen_header.dart';

/// Flats that have submitted a UPI payment screenshot, awaiting the
/// admin's manual confirmation (spec §6 — no payment gateway, no
/// auto-reconciliation, this is the whole confirmation step) — plus a
/// "Confirmed" tab, so a screenshot is still reachable as an audit trail
/// after confirming rather than just vanishing off the pending list.
class ConfirmPaymentsScreen extends StatefulWidget {
  const ConfirmPaymentsScreen({super.key});

  @override
  State<ConfirmPaymentsScreen> createState() => _ConfirmPaymentsScreenState();
}

class _ConfirmPaymentsScreenState extends State<ConfirmPaymentsScreen> {
  bool _showConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final pending =
        society.currentMonth.bills
            .where((b) => b.status == BillStatus.screenshotUploaded)
            .toList()
          ..sort((a, b) {
            final aTime = a.screenshotSubmittedAt;
            final bTime = b.screenshotSubmittedAt;
            if (aTime == null || bTime == null) return 0;
            return aTime.compareTo(bTime);
          });
    final confirmed =
        society.currentMonth.bills
            .where((b) => b.status == BillStatus.confirmed)
            .toList()
          ..sort((a, b) {
            final aTime = a.confirmedAt;
            final bTime = b.confirmedAt;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

    final list = _showConfirmed ? confirmed : pending;
    final totalPaise = list.fold<int>(0, (sum, b) => sum + b.amountDuePaise);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('confirmPayments')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _StatusTabs(
                  showConfirmed: _showConfirmed,
                  pendingCount: pending.length,
                  confirmedCount: confirmed.length,
                  onChanged: (v) => setState(() => _showConfirmed = v),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: _showConfirmed
                            ? Icons.receipt_long_rounded
                            : Icons.task_alt_rounded,
                        title: AppLocalizations.t(
                          _showConfirmed
                              ? 'noConfirmedPaymentsTitle'
                              : 'noPaymentsPendingTitle',
                        ),
                        subtitle: AppLocalizations.t(
                          _showConfirmed
                              ? 'noConfirmedPaymentsSub'
                              : 'noPaymentsPendingSub',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          _StatusSummary(
                            confirmed: _showConfirmed,
                            count: list.length,
                            totalPaise: totalPaise,
                          ),
                          const SizedBox(height: 16),
                          for (final bill in list)
                            _PaymentCard(
                              bill: bill,
                              residentName: society
                                  .flatByNumber(bill.flatNumber)
                                  ?.residentName,
                              onConfirm: _showConfirmed
                                  ? null
                                  : () => context
                                        .read<SocietyProvider>()
                                        .confirmPayment(bill.flatNumber),
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

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.showConfirmed,
    required this.pendingCount,
    required this.confirmedCount,
    required this.onChanged,
  });

  final bool showConfirmed;
  final int pendingCount;
  final int confirmedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatusTab(
              label: '${AppLocalizations.t('pending')} ($pendingCount)',
              selected: !showConfirmed,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _StatusTab(
              label: '${AppLocalizations.t('confirmedTabLabel')} ($confirmedCount)',
              selected: showConfirmed,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? Colors.white : AppTheme.textLight,
          ),
        ),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.confirmed,
    required this.count,
    required this.totalPaise,
  });

  final bool confirmed;
  final int count;
  final int totalPaise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confirmed ? AppTheme.sageBg : AppTheme.amberBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              confirmed
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_bottom_rounded,
              color: confirmed ? AppTheme.success : AppTheme.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmed
                      ? '$count ${AppLocalizations.t('confirmedTabLabel')}'
                      : '$count ${AppLocalizations.t('awaitingConfirmationLabel')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  formatPaise(totalPaise),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: confirmed ? AppTheme.success : AppTheme.amber,
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.bill,
    required this.residentName,
    required this.onConfirm,
  });

  final Bill bill;
  final String? residentName;

  /// Null means this payment is already confirmed — hides the Confirm
  /// button and shows a confirmed timestamp instead.
  final VoidCallback? onConfirm;

  String _statusLine(BuildContext context) {
    if (onConfirm == null) {
      final confirmedAt = bill.confirmedAt;
      if (confirmedAt == null) return AppLocalizations.t('confirmedOnLabel');
      return '${AppLocalizations.t('confirmedOnLabel')} · ${DateFormat('MMM d, h:mm a').format(confirmedAt)}';
    }
    final submittedAt = bill.screenshotSubmittedAt;
    if (submittedAt == null) return '';
    final diff = DateTime.now().difference(submittedAt);
    if (diff.inMinutes < 1) return AppLocalizations.t('justNow');
    if (diff.inHours < 1) {
      return '${diff.inMinutes} ${AppLocalizations.t('minutesAgoSuffix')}';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} ${AppLocalizations.t('hoursAgoSuffix')}';
    }
    return '${diff.inDays} ${AppLocalizations.t('daysAgoSuffix')}';
  }

  @override
  Widget build(BuildContext context) {
    final flatSuffix = bill.flatNumber.length >= 2
        ? bill.flatNumber.substring(bill.flatNumber.length - 2)
        : bill.flatNumber;
    final statusLine = _statusLine(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge.text(flatSuffix),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      residentName?.isNotEmpty == true
                          ? '${AppLocalizations.t('flat')} ${bill.flatNumber} · $residentName'
                          : '${AppLocalizations.t('flat')} ${bill.flatNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (statusLine.isNotEmpty)
                      Text(
                        statusLine,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatPaise(bill.amountDuePaise),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final url = bill.paymentScreenshotUrl;
              if (url == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.t('featureComingSoon')),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenNetworkPhoto(url: url),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.t('viewScreenshotLabel'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textLight,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (onConfirm != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(AppLocalizations.t('confirmBtn')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
