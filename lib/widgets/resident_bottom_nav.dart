import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/localization/app_localizations.dart';

/// The resident bottom-nav shell: Building / Community / Profile.
/// Community tab is omitted entirely when the building hasn't joined an
/// association — [currentIndex]/[onTap] operate on whichever tab set is
/// currently showing.
class ResidentBottomNav extends StatelessWidget {
  const ResidentBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.showCommunity,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showCommunity;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.home_filled, AppLocalizations.t('navBuilding')),
      if (showCommunity)
        (Icons.groups_rounded, AppLocalizations.t('navCommunity')),
      (Icons.person_rounded, AppLocalizations.t('navProfile')),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      padding: const EdgeInsets.only(top: 8),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavItem(
                icon: items[i].$1,
                label: items[i].$2,
                isActive: currentIndex == i,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.textMedium;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
