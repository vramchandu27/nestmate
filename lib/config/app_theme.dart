import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'localization/app_localizations.dart';

class AppTheme {
  // Primary brand color — Deep Teal
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);

  // Welcome feature-card accents
  static const Color accentBlue = Color(0xFFCCFBF1);
  static const Color accentAmber = Color(0xFFFDF3E0);
  static const Color accentTeal = Color(0xFFE2F4F1);

  // Semantic pill/badge/icon-chip tokens (prototype's --clay-bg/--sage/--amber/--rose)
  static const Color clayBg = Color(0xFFDDE8FB);
  static const Color sage = Color(0xFF2E9E6B);
  static const Color sageDark = Color(0xFF227A52);
  static const Color sageBg = Color(0xFFDCEFE4);
  static const Color amber = Color(0xFFB7791F);
  static const Color amberBg = Color(0xFFF9EECF);
  static const Color rose = Color(0xFFB0485A);
  static const Color roseBg = Color(0xFFF7E3E6);

  // Text colors
  static const Color textDark = Color(0xFF182234);
  static const Color textMedium = Color(0xFF4A5570);
  static const Color textLight = Color(0xFF8B93A7);

  // Background
  static const Color background = Color(0xFFF3F6FB);

  // Cards
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Success, error, warning
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Borders
  static const Color borderColor = Color(0xFFE8ECF1);
  static const Color line = Color(0xFFE2E8F2);
  static const Color line2 = Color(0xFFEEF2F9);

  // Prototype's --shadow-sm / --shadow — a navy-tinted shadow (not pure
  // black), used on nearly every card/row/pill across the app.
  static const Color _shadowTint = Color(0xFF182C50);
  static List<BoxShadow> get shadowSm => [
    BoxShadow(color: _shadowTint.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: _shadowTint.withValues(alpha: 0.15), blurRadius: 44, offset: const Offset(0, 14)),
  ];
  static List<BoxShadow> get shadowClay => [
    BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  /// Registers Noto Sans Telugu / Devanagari as glyph fallbacks so Telugu
  /// and Hindi text never tofu-box when the primary font (Plus Jakarta
  /// Sans / Fraunces, neither of which cover those scripts) is in effect.
  /// Both are always included regardless of the active language — harmless
  /// to register, and avoids threading the language through every caller.
  static List<String> get _scriptFallbacks => [
    GoogleFonts.notoSansTelugu().fontFamily!,
    GoogleFonts.notoSansDevanagari().fontFamily!,
  ];

  static TextStyle _body({
    required double size,
    required FontWeight weight,
    Color color = textDark,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: _scriptFallbacks);
  }

  /// Fraunces is the prototype's serif "display" heading font — but it has
  /// no Telugu glyphs, so Telugu headings fall back to the body font
  /// (Plus Jakarta Sans + Noto Sans Telugu), matching the prototype's own
  /// `disp()` helper which only applies the display class in English.
  static TextStyle _heading({
    required double size,
    required FontWeight weight,
    required bool serif,
    Color color = textDark,
    double? height,
    double? letterSpacing,
  }) {
    if (!serif) {
      return _body(size: size, weight: weight, color: color, height: height, letterSpacing: letterSpacing);
    }
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Pulls today's heading font (Fraunces in English, Plus Jakarta Sans +
  /// Noto Sans Telugu in Telugu) so screens can apply the prototype's
  /// "display" treatment — used on big page headings AND large money/
  /// percentage figures (the prototype runs its `.amt`/`.rate`/`.pct`
  /// numbers through the same serif face) — without being tied to the
  /// theme's preset display sizes.
  static TextStyle displayStyle(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color color = textDark,
    double? height,
    double? letterSpacing,
  }) {
    final base = Theme.of(context).textTheme.displayLarge;
    return TextStyle(
      fontFamily: base?.fontFamily,
      fontFamilyFallback: base?.fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Get ThemeData with NestMate design. [language] controls whether
  /// headings use the Fraunces serif face (English) or stay on the body
  /// font (Telugu, which Fraunces can't render).
  static ThemeData lightTheme({AppLanguage language = AppLanguage.english}) {
    final serif = language == AppLanguage.english;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accentTeal,
        surface: background,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: cardBackground,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _body(size: 18, weight: FontWeight.w600, color: textDark),
      ),
      textTheme: TextTheme(
        // Headings — Fraunces serif (English only)
        displayLarge: _heading(size: 32, weight: FontWeight.w700, serif: serif, height: 1.15),
        displayMedium: _heading(size: 28, weight: FontWeight.w700, serif: serif, height: 1.15),
        displaySmall: _heading(size: 24, weight: FontWeight.w700, serif: serif, height: 1.2),
        headlineMedium: _heading(size: 20, weight: FontWeight.w600, serif: serif, height: 1.25),
        headlineSmall: _heading(size: 18, weight: FontWeight.w600, serif: serif, height: 1.3),
        // Body text — Plus Jakarta Sans
        bodyLarge: _body(size: 16, weight: FontWeight.w500, color: textMedium, height: 1.5),
        bodyMedium: _body(size: 14, weight: FontWeight.w500, color: textMedium, height: 1.5),
        bodySmall: _body(size: 12, weight: FontWeight.w400, color: textLight, height: 1.5),
        // Labels — Plus Jakarta Sans
        labelLarge: _body(size: 14, weight: FontWeight.w600, color: textDark, height: 1.3),
        labelMedium: _body(size: 12, weight: FontWeight.w600, color: textMedium, height: 1.3),
        labelSmall: _body(size: 11, weight: FontWeight.w500, color: textLight, height: 1.3),
      ).apply(fontFamilyFallback: _scriptFallbacks),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _body(size: 16, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _body(size: 16, weight: FontWeight.w700, color: primary),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: _body(size: 14, weight: FontWeight.w500, color: textMedium),
        hintStyle: _body(size: 14, weight: FontWeight.w400, color: textLight),
      ),
    );
  }
}
