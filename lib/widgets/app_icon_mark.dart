import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The app's brand mark — a white rounded box with the same
/// Icons.apartment_rounded glyph as the launcher icon and native splash
/// screen. Wrapped in a single shared [Hero] (tag `'app-icon'`) so
/// whichever two screens both show this mark during a navigation (the
/// [_AuthGate] loading screen and [LanguageSelectionScreen], right now)
/// get a smooth flight animation between their two sizes/positions
/// instead of a hard cut — the icon visually "arrives" into its header
/// spot rather than the screen just changing underneath it.
class AppIconMark extends StatelessWidget {
  const AppIconMark({super.key, this.size = 80, this.iconSize = 40});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'app-icon',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.apartment_rounded,
          color: AppTheme.primary,
          size: iconSize,
        ),
      ),
    );
  }
}
