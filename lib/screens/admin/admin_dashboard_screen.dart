import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../models/bill.dart';
import '../../models/issue_report.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/collection_ring.dart';
import '../../widgets/nav_list_tile.dart';
import '../../widgets/waving_hand.dart';
import 'add_people_screen.dart';
import 'block_setup_screen.dart';
import 'confirm_payments_screen.dart';
import 'expenses_screen.dart';
import 'flats_management_screen.dart';
import 'issues_screen.dart';
import 'add_notice_screen.dart';
import 'admin_profile_screen.dart';
import 'join_association_screen.dart';
import 'notifications_screen.dart';
import 'transfer_admin_screen.dart';
import 'work_list_screen.dart';

/// Admin home: building overview, collection progress, and the nav tiles
/// into every operational flow (expenses, water calc via expenses,
/// confirm payments, flats & residents, association).
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final society = context.watch<SocietyProvider>();
    final building = society.building;
    final pendingConfirmCount = society.currentMonth.bills
        .where((b) => b.status == BillStatus.screenshotUploaded)
        .length;
    final openIssueCount = society.issues
        .where((i) => i.status != IssueStatus.resolved)
        .length;

    final pendingNotifications = pendingConfirmCount + openIssueCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminProfileScreen(),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primary,
                      backgroundImage: app.userPhotoUrl != null
                          ? NetworkImage(app.userPhotoUrl!)
                          : null,
                      child: app.userPhotoUrl != null
                          ? null
                          : Text(
                              (app.userName ?? building.adminName).isNotEmpty
                                  ? (app.userName ?? building.adminName)[0]
                                        .toUpperCase()
                                  : '?',
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
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminProfileScreen(),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.t('hi'),
                                style: const TextStyle(
                                  color: AppTheme.textLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const WavingHand(),
                            ],
                          ),
                          Text(
                            app.userName ?? building.adminName,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        if (pendingNotifications > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 17,
                              height: 17,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 2),
                                ),
                              ),
                              child: Text(
                                pendingNotifications > 9
                                    ? '9+'
                                    : '$pendingNotifications',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _confirmLogout(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.textMedium,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlockSetupScreen()),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      decoration: const BoxDecoration(color: AppTheme.primary),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -36,
                            right: -24,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -50,
                            left: -30,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.apartment_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            AppLocalizations.t('edit'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  building.name,
                                  style: AppTheme.displayStyle(
                                    context,
                                    size: 22,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${society.currentMonth.label} · ${society.flats.length} ${AppLocalizations.t('flats').toLowerCase()}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (building.joinCode.isNotEmpty)
                                      _GlassPill(
                                        icon: Icons.qr_code_rounded,
                                        text: building.joinCode,
                                        onTap: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: building.joinCode,
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                AppLocalizations.t(
                                                  'joinCodeCopied',
                                                ),
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    _GlassPill(
                                      icon: Icons.trending_up_rounded,
                                      text:
                                          '${(society.collectionPercent * 100).round()}% ${AppLocalizations.t('collected').toLowerCase()}',
                                      animateIcon: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CollectionRing(
                      percent: society.collectionPercent,
                      centerLabel:
                          '${(society.collectionPercent * 100).round()}%',
                      centerSubLabel: AppLocalizations.t('paid').toUpperCase(),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: [
                          _StatChip(
                            icon: Icons.check_circle_rounded,
                            color: AppTheme.success,
                            background: AppTheme.sageBg,
                            label: AppLocalizations.t('collected'),
                            value: formatPaise(society.collectedPaise),
                          ),
                          const SizedBox(height: 10),
                          _StatChip(
                            icon: Icons.hourglass_bottom_rounded,
                            color: AppTheme.warning,
                            background: AppTheme.amberBg,
                            label: AppLocalizations.t('pending'),
                            value: formatPaise(society.pendingPaise),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              NavListTile(
                icon: Icons.receipt_rounded,
                title: AppLocalizations.t('calculateBills'),
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                ),
              ),
              NavListTile(
                icon: Icons.savings_rounded,
                title: AppLocalizations.t('reserveFundLabel'),
                trailingText: formatPaise(society.building.reserveFundPaise),
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                // The Expenses screen already shows the full picture —
                // the balance, every expense (with a badge for the ones
                // paid from reserve), and the top-up action — rather than
                // duplicating that as a second screen.
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                ),
              ),
              NavListTile(
                icon: Icons.payment_rounded,
                title: AppLocalizations.t('confirmPayments'),
                badge: pendingConfirmCount > 0 ? '$pendingConfirmCount' : null,
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                badgeColor: AppTheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConfirmPaymentsScreen(),
                  ),
                ),
              ),
              NavListTile(
                icon: Icons.report_problem_rounded,
                title: AppLocalizations.t('reportIssue'),
                badge: openIssueCount > 0 ? '$openIssueCount' : null,
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                badgeColor: AppTheme.error,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IssuesScreen()),
                ),
              ),
              NavListTile(
                icon: Icons.campaign_rounded,
                title: AppLocalizations.t('communityNotices'),
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddNoticeScreen()),
                ),
              ),
              NavListTile(
                icon: Icons.checklist_rounded,
                title: AppLocalizations.t('workListTitle'),
                badge: society.pendingWorkItemCount > 0
                    ? '${society.pendingWorkItemCount}'
                    : null,
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                badgeColor: AppTheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WorkListScreen()),
                ),
              ),
              NavListTile(
                icon: Icons.people_rounded,
                title: AppLocalizations.t('flatsResidentsTitle'),
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FlatsManagementScreen(),
                  ),
                ),
              ),
              NavListTile(
                icon: Icons.groups_rounded,
                title: AppLocalizations.t('associationRow'),
                trailingText: society.association.joined
                    ? AppLocalizations.t('joinedLabel')
                    : null,
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JoinAssociationScreen(),
                  ),
                ),
              ),
              NavListTile(
                icon: Icons.swap_horizontal_circle_rounded,
                title: AppLocalizations.t('transferAdminRole'),
                iconBackground: AppTheme.primary,
                iconColor: Colors.white,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransferAdminScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.t('flatsResidentsTitle'),
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final flat in society.flats)
                    _FlatStatusChip(
                      flatNumber: flat.flatNumber,
                      status: society.currentMonth
                          .billFor(flat.flatNumber)
                          ?.status,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: society.flats.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPeopleScreen()),
              ),
              label: Text(AppLocalizations.t('addFlatBtn')),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('logout')),
        content: Text(AppLocalizations.t('confirmLogout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            onPressed: () => performLogout(context),
            child: Text(AppLocalizations.t('logout')),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.icon,
    required this.text,
    this.animateIcon = false,
    this.onTap,
  });

  final IconData icon;
  final String text;

  /// Gives the icon a gentle, continuous upward nudge — used for the
  /// trending-up "collected" pill, not the QR-code one.
  final bool animateIcon;

  /// When set, the pill becomes a real control and grows a trailing copy
  /// affordance — without one the join code read as decoration, and admins
  /// had no reason to think the thing they needed to send their residents
  /// was sitting in it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: onTap == null ? 0.16 : 0.24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          animateIcon
              ? _BouncingIcon(icon: icon)
              : Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, color: Colors.white, size: 12),
          ],
        ],
      ),
    );
    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      ),
    );
  }
}

/// A small, continuous upward bob for an icon — just enough life to draw
/// the eye to the collection-rate pill without being distracting. Falls
/// back to a static icon when the OS's reduce-motion setting is on.
class _BouncingIcon extends StatefulWidget {
  const _BouncingIcon({required this.icon});

  final IconData icon;

  @override
  State<_BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<_BouncingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _offset = Tween<double>(
    begin: 0,
    end: -2.5,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Icon(widget.icon, color: Colors.white, size: 13);
    }
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _offset.value),
        child: child,
      ),
      child: Icon(widget.icon, color: Colors.white, size: 13),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMedium,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
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

class _FlatStatusChip extends StatelessWidget {
  const _FlatStatusChip({required this.flatNumber, required this.status});

  final String flatNumber;
  final BillStatus? status;

  Color _color() {
    switch (status) {
      case BillStatus.confirmed:
        return AppTheme.success;
      case BillStatus.screenshotUploaded:
        return AppTheme.warning;
      case BillStatus.unpaid:
      case null:
        return AppTheme.textLight;
    }
  }

  String _icon() {
    switch (status) {
      case BillStatus.confirmed:
        return '✓';
      case BillStatus.screenshotUploaded:
        return '⏳';
      case BillStatus.unpaid:
      case null:
        return '○';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            flatNumber,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _icon(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
