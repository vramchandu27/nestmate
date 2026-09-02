import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The filled, borderless-until-focused text field style shared by every
/// onboarding auth form (Login/Signup/Admin Signup) — including the
/// red-ringed error/focused-error states, so a validator error reads
/// consistently with the rest of the field's look instead of falling
/// back to Flutter's default red-underline decoration.
InputDecoration authFieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder side({Color? color, double width = 0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color!, width: width),
      );

  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(
      icon,
      color: AppTheme.primary.withValues(alpha: 0.7),
      size: 22,
    ),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppTheme.background.withValues(alpha: 0.5),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    border: side(),
    enabledBorder: side(),
    focusedBorder: side(color: AppTheme.primary, width: 2),
    errorBorder: side(color: AppTheme.error, width: 1.5),
    focusedErrorBorder: side(color: AppTheme.error, width: 2),
    errorStyle: const TextStyle(
      color: AppTheme.error,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    errorMaxLines: 2,
  );
}
