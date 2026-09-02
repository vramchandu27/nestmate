import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/screen_header.dart';

/// Join / manage the multi-building association that unlocks the
/// Community tab for every resident once this building has joined.
class JoinAssociationScreen extends StatefulWidget {
  const JoinAssociationScreen({super.key});

  @override
  State<JoinAssociationScreen> createState() => _JoinAssociationScreenState();
}

class _JoinAssociationScreenState extends State<JoinAssociationScreen> {
  final _codeCtrl = TextEditingController(text: 'SPV-2024');

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final association = society.association;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('associationRow')),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: association.joined
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                22,
                                20,
                                18,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primary,
                                    AppTheme.primaryDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    association.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${AppLocalizations.t('joinedTo')} · ${association.buildingCount} buildings',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppCard(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    AppLocalizations.t('joinedLabel'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton(
                              onPressed: () => context
                                  .read<SocietyProvider>()
                                  .leaveAssociation(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                              ),
                              child: Text(
                                AppLocalizations.t('leaveAssociation'),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            const Center(
                              child: Icon(
                                Icons.groups_rounded,
                                size: 46,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.t('joinSub'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textMedium,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              AppLocalizations.t('associationCodeLabel'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _codeCtrl,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<SocietyProvider>()
                                  .joinAssociation(_codeCtrl.text.trim()),
                              child: Text(AppLocalizations.t('joinBtn')),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Text(
                                AppLocalizations.t('notJoinedLabel'),
                                style: const TextStyle(
                                  color: AppTheme.textLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
