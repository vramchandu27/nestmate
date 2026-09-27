import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_icon_mark.dart';

/// Language Selection Screen
///
/// The premium first impression of the app.
class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Gradient Element
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.05),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),

                    // App Logo/Icon
                    const AppIconMark(),

                    const SizedBox(height: 32),

                    // Brand & Tagline
                    Text(
                      'Resko',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.t('tagline'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textMedium,
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Selection Instruction
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.t('selectLanguage'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Selection Cards
                    _LanguageCard(
                      label: AppLocalizations.t('english'),
                      subtext: 'Primary international language',
                      language: AppLanguage.english,
                      icon: 'A',
                      accentColor: AppTheme.accentBlue,
                    ),

                    const SizedBox(height: 20),

                    _LanguageCard(
                      label: AppLocalizations.t('hindi'),
                      subtext: 'हमारी राष्ट्रीय भाषा',
                      language: AppLanguage.hindi,
                      icon: 'हिं',
                      accentColor: AppTheme.accentAmber,
                    ),

                    const SizedBox(height: 20),

                    _LanguageCard(
                      label: AppLocalizations.t('telugu'),
                      subtext: 'మన ప్రాంతీయ భాష',
                      language: AppLanguage.telugu,
                      icon: 'తె',
                      accentColor: AppTheme.accentTeal,
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatefulWidget {
  final String label;
  final String subtext;
  final AppLanguage language;
  final String icon;
  final Color accentColor;

  const _LanguageCard({
    required this.label,
    required this.subtext,
    required this.language,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        _handleSelection(context);
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(
          _isHovered ? 0.98 : 1.0,
          _isHovered ? 0.98 : 1.0,
          1.0,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovered ? AppTheme.primary : Colors.white,
            width: 2,
          ),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.icon,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtext,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textLight.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSelection(BuildContext context) {
    context.read<AppProvider>().setLanguage(widget.language);
    Navigator.pushReplacementNamed(context, '/welcome');
  }
}
