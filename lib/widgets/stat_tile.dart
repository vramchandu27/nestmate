import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'app_card.dart';

/// A value+label stat card, e.g. "₹52,300 / Collected" or "15 / Bills ready".
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTheme.displayStyle(
              context,
              size: 21,
              weight: FontWeight.w800,
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
