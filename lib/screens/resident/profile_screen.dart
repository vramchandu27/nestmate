import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/language_toggle.dart';
import 'personal_expenses_screen.dart';

/// Resident profile tab: identity, flat/association info, language
/// toggle, and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final society = context.watch<SocietyProvider>();
    final flatNumber = app.flatNumber ?? '';
    final flat = society.flatByNumber(flatNumber);
    final name = app.userName ?? flat?.residentName ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final totalPaid = society.totalPaidPaiseForFlat(flatNumber);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  AvatarPicker(
                    photoUrl: app.userPhotoUrl,
                    initial: initial,
                    onPicked: (file) => updateProfilePhoto(context, file),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${AppLocalizations.t('flat')} $flatNumber · ${society.building.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _InfoRow(
              icon: Icons.home_rounded,
              label: AppLocalizations.t('yourFlat'),
              value: flatNumber,
            ),
            if (society.association.joined)
              _InfoRow(
                icon: Icons.groups_rounded,
                label: AppLocalizations.t('associationRow'),
                value: society.association.name,
              ),
            _InfoRow(
              icon: Icons.phone_rounded,
              label: AppLocalizations.t('phoneNumber'),
              value: app.userPhone ?? flat?.phone ?? '',
            ),
            _InfoRow(
              icon: Icons.check_circle_rounded,
              label: AppLocalizations.t('totalPaidSoFar'),
              value: formatPaise(totalPaid),
            ),
            AppCard(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalExpensesScreen(),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      AppLocalizations.t('myPersonalExpensesCard'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
            ),
            AppCard(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      AppLocalizations.t('language'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const LanguageToggle(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => performLogout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
              ),
              child: Text(AppLocalizations.t('logout')),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
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

