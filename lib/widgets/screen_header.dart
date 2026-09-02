import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/localization/app_localizations.dart';

/// The app's standard in-body header: a circular back button beside a bold
/// title, instead of a separate Material AppBar strip. Used at the top of
/// a screen's own [SafeArea]/[Column], not as [Scaffold.appBar].
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.showBackButton = true,
  });

  final String title;

  /// Defaults to [Navigator.pop] when omitted.
  final VoidCallback? onBack;

  /// Optional trailing action (e.g. logout, save) shown at the row's end.
  final Widget? trailing;

  /// Set false for a root/tab screen with nothing to pop back to (e.g. the
  /// admin or committee dashboard, landed on via a route replacement).
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (showBackButton) ...[
            _HeaderIconButton(
              icon: Icons.chevron_left_rounded,
              onPressed: onBack ?? () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textDark),
        onPressed: onPressed,
        tooltip: AppLocalizations.t('back'),
      ),
    );
  }
}
