import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The rounded white "card" container used on nearly every screen:
/// soft shadow, rounded corners, optional tap handling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 15,
    this.onTap,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: boxShadow ?? AppTheme.shadowSm,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;

    return GestureDetector(onTap: onTap, child: card);
  }
}
