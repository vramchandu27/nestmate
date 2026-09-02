import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

/// Enum for supported languages
enum AppLanguage { english, hindi, telugu }

/// Main localization class for NestMate
class AppLocalizations {
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('hi', 'IN'),
    Locale('te', 'IN'),
  ];

  static const Locale defaultLocale = Locale('en', 'US');

  static Map<String, String> _currentTranslations =
      AppLocalizationsEn.translations;
  static AppLanguage _currentLanguage = AppLanguage.english;

  /// Get current language
  static AppLanguage get currentLanguage => _currentLanguage;

  /// Set language and return translations
  static Map<String, String> setLanguage(AppLanguage language) {
    _currentLanguage = language;
    switch (language) {
      case AppLanguage.english:
        _currentTranslations = AppLocalizationsEn.translations;
        break;
      case AppLanguage.hindi:
        _currentTranslations = AppLocalizationsHi.translations;
        break;
      case AppLanguage.telugu:
        _currentTranslations = AppLocalizationsTe.translations;
        break;
    }
    return _currentTranslations;
  }

  /// Get translated string
  static String t(String key, {String defaultValue = ''}) {
    return _currentTranslations[key] ?? defaultValue;
  }

  /// Get translated string with parameters
  static String tr(
    String key,
    Map<String, String> params, {
    String defaultValue = '',
  }) {
    String value = _currentTranslations[key] ?? defaultValue;
    params.forEach((k, v) {
      value = value.replaceAll(':$k', v);
    });
    return value;
  }

  /// Get locale from AppLanguage
  static Locale getLocale(AppLanguage language) {
    switch (language) {
      case AppLanguage.english:
        return const Locale('en', 'US');
      case AppLanguage.hindi:
        return const Locale('hi', 'IN');
      case AppLanguage.telugu:
        return const Locale('te', 'IN');
    }
  }

  /// Get AppLanguage from Locale
  static AppLanguage getLanguageFromLocale(Locale locale) {
    if (locale.languageCode == 'te') {
      return AppLanguage.telugu;
    }
    if (locale.languageCode == 'hi') {
      return AppLanguage.hindi;
    }
    return AppLanguage.english;
  }
}
