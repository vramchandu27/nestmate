import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum PillStatus { paid, pending, open, inProgress, resolved, exempt }

/// The small colored status pill used throughout (bill status, issue
/// status, exempt tags): "Paid", "Pending", "In progress", etc.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.status});

  final String label;
  final PillStatus status;

  (Color bg, Color fg) get _colors {
    switch (status) {
      case PillStatus.paid:
      case PillStatus.resolved:
        return (AppTheme.sageBg, AppTheme.sageDark);
      case PillStatus.pending:
      case PillStatus.inProgress:
        return (AppTheme.amberBg, AppTheme.amber);
      case PillStatus.open:
        return (AppTheme.roseBg, AppTheme.rose);
      case PillStatus.exempt:
        return (
          AppTheme.textLight.withValues(alpha: 0.15),
          AppTheme.textMedium,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
