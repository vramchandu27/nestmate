import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/collection_ring.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_tile.dart';

/// Read-only committee view: collection progress and the flat roster.
/// No mutating actions (no expenses, no water calc, no payment
/// confirmation, no adding flats) — per spec, committee is read-mostly.
class CommitteeDashboardScreen extends StatelessWidget {
  const CommitteeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final society = context.watch<SocietyProvider>();
    final building = society.building;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: building.name,
                showBackButton: false,
                trailing: GestureDetector(
                  onTap: () => performLogout(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.textMedium,
                      size: 19,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      '${AppLocalizations.t('hi')} ${app.userName ?? AppLocalizations.t('committee')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.t('committeeEnabledLabel'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CollectionRing(
                            percent: society.collectionPercent,
                            centerLabel:
                                '${(society.collectionPercent * 100).round()}%',
                            centerSubLabel: AppLocalizations.t(
                              'paid',
                            ).toUpperCase(),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.t('collected'),
                                  style: const TextStyle(
                                    color: AppTheme.textLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  formatPaise(society.collectedPaise),
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${society.flats.length}',
                            label: AppLocalizations.t('totalFlats'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: formatPaise(society.pendingPaise),
                            label: AppLocalizations.t('pending'),
                            valueColor: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.t('flatsResidentsTitle'),
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final flat in society.flats)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${AppLocalizations.t('flat')} ${flat.flatNumber} · ${flat.residentName}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
