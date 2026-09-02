import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A rounded-square icon or initials container — nav-tile leading icons,
/// list-row leading icons, and avatar-with-initials chips.
class IconBadge extends StatelessWidget {
  const IconBadge.icon(
    this.icon, {
    super.key,
    this.size = 42,
    this.background = AppTheme.accentBlue,
    this.color = AppTheme.primary,
  }) : text = null;

  const IconBadge.text(
    this.text, {
    super.key,
    this.size = 42,
    this.background = AppTheme.accentBlue,
    this.color = AppTheme.primary,
  }) : icon = null;

  final IconData? icon;
  final String? text;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: icon != null
          ? Icon(icon, color: color, size: size * 0.46)
          : Text(
              text!,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.33,
              ),
            ),
    );
  }
}
