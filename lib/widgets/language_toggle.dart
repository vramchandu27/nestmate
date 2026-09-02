import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/localization/app_localizations.dart';
import '../providers/app_provider.dart';

/// EN/HI/TE sliding pill toggle — used on both the resident and admin
/// profile screens.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangBtn(
            label: 'EN',
            selected: app.language == AppLanguage.english,
            onTap: () => app.setLanguage(AppLanguage.english),
          ),
          _LangBtn(
            label: 'हिं',
            selected: app.language == AppLanguage.hindi,
            onTap: () => app.setLanguage(AppLanguage.hindi),
          ),
          _LangBtn(
            label: 'తె',
            selected: app.language == AppLanguage.telugu,
            onTap: () => app.setLanguage(AppLanguage.telugu),
          ),
        ],
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  const _LangBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
