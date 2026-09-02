import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The small uppercase muted label used above list groups
/// (e.g. "EARLIER MONTHS", "FLATS & RESIDENTS").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: AppTheme.textLight,
        letterSpacing: 0.9,
      ),
    );

    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: text,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [text, trailing!],
      ),
    );
  }
}
