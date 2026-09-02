import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';
import 'add_people_screen.dart';

/// Standalone flats/residents list — the ongoing management view, as
/// opposed to [AddPeopleScreen]'s first-run setup flow.
class FlatsManagementScreen extends StatelessWidget {
  const FlatsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flats = context.watch<SocietyProvider>().flats;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('flatsResidentsTitle')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddPeopleScreen(),
                        ),
                      ),
                      child: Text('+ ${AppLocalizations.t('addFlatBtn')}'),
                    ),
                    const SizedBox(height: 16),
                    for (final f in flats)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            IconBadge.text(
                              f.flatNumber.length >= 2
                                  ? f.flatNumber.substring(
                                      f.flatNumber.length - 2,
                                    )
                                  : f.flatNumber,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocalizations.t('flat')} ${f.flatNumber} · ${f.residentName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    f.phone,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (f.tankerExempt)
                              StatusPill(
                                label: AppLocalizations.t('exemptTag'),
                                status: PillStatus.exempt,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
