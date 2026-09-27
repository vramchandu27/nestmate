import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';

/// NestMate - Welcome Screen
///
/// Pre-auth and tenant-neutral — shown before the app knows which
/// building the user belongs to, so it must never show a specific
/// building's name. Matches the prototype's layout: icon, single-line
/// heading, subtitle, three colored feature rows, faded building photo
/// behind everything, plain full-width "Get started" button.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Faded building photo behind everything.
          Positioned.fill(
            child: Opacity(
              opacity: 0.55,
              child: Image.asset(
                'assets/images/building.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Light scrim so the photo reads as a faint backdrop, not a
          // competing image — matches the prototype's top/bottom fade.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background.withValues(alpha: 0.55),
                    AppTheme.background.withValues(alpha: 0.85),
                    AppTheme.background.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.32),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Text(
                            '🏡',
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          AppLocalizations.t('welcome'),
                          style: AppTheme.displayStyle(
                            context,
                            size: 30,
                            weight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.t('tagline'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppLocalizations.t('welcomeSubtitle'),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textMedium,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _FeatureRow(
                          icon: Icons.receipt_long_rounded,
                          title: AppLocalizations.t('clearMonthlyBills'),
                          description: AppLocalizations.t(
                            'seeExactlyWhatYouOwe',
                          ),
                          background: AppTheme.accentBlue,
                          iconColor: const Color(0xFF3B82F6),
                        ),
                        const SizedBox(height: 11),
                        _FeatureRow(
                          icon: Icons.bolt_rounded,
                          title: AppLocalizations.t('payInSeconds'),
                          description: AppLocalizations.t(
                            'upiPaymentUploadProof',
                          ),
                          background: AppTheme.accentAmber,
                          iconColor: const Color(0xFFB7791F),
                        ),
                        const SizedBox(height: 11),
                        _FeatureRow(
                          icon: Icons.water_drop_rounded,
                          title: AppLocalizations.t('fairWaterBilling'),
                          description: AppLocalizations.t(
                            'chargedByActualUsage',
                          ),
                          background: AppTheme.accentTeal,
                          iconColor: const Color(0xFF0F6B5E),
                        ),
                        const SizedBox(height: 18),
                        _PersonalTrackerCard(
                          onTap: () =>
                              Navigator.pushNamed(context, '/personal-login'),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.t('getStarted'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The standalone entry point for someone who wants nothing but the
/// personal expense tracker — not a resident, not an admin. Deliberately
/// styled apart from the plain informational [_FeatureRow]s above it (a
/// dashed-look primary border, a "Start now" chip, a chevron) so it reads
/// as something to tap, not just another fact about the app.
class _PersonalTrackerCard extends StatelessWidget {
  const _PersonalTrackerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.sage.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.sageBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.sageDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.t('personalTrackerCta'),
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppLocalizations.t('personalTrackerCtaSub'),
                      style: const TextStyle(
                        color: AppTheme.textMedium,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.sageDark,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.background,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textMedium,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
