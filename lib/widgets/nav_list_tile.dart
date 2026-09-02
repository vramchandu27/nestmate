import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'app_card.dart';
import 'icon_badge.dart';

/// Icon + title (+ optional subtitle) + optional badge + chevron, tappable
/// row. Used for admin dashboard action tiles, expense/flat/person rows.
class NavListTile extends StatelessWidget {
  const NavListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailingText,
    this.iconBackground = AppTheme.accentBlue,
    this.iconColor = AppTheme.primary,
    this.badgeColor = AppTheme.primary,
    this.showChevron = true,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final String? trailingText;
  final Color iconBackground;
  final Color iconColor;
  final Color badgeColor;
  final bool showChevron;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      boxShadow: boxShadow,
      onTap: onTap,
      child: Row(
        children: [
          IconBadge.icon(icon, background: iconBackground, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailingText!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (showChevron)
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
        ],
      ),
    );
  }
}
