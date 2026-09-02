import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';

/// Add-a-flat form plus the running list of flats already added. Used
/// both for first-time building setup and later as a standalone entry
/// point (see [FlatsManagementScreen]).
class AddPeopleScreen extends StatefulWidget {
  const AddPeopleScreen({super.key});

  @override
  State<AddPeopleScreen> createState() => _AddPeopleScreenState();
}

class _AddPeopleScreenState extends State<AddPeopleScreen> {
  final _flatCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _exempt = false;
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _flatCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFlat(SocietyProvider society) async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => society.addFlat(
        flatNumber: _flatCtrl.text.trim(),
        residentName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        tankerExempt: _exempt,
      ),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _flatCtrl.clear();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _exempt = false;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final flats = society.flats;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('addFlatsResidents')),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        AppLocalizations.t('addPeopleSub'),
                        style: const TextStyle(
                          color: AppTheme.textMedium,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _flatCtrl,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.t('flatNumber'),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? AppLocalizations.t('fieldRequired')
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameCtrl,
                              enabled: !_isLoading,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.t(
                                  'residentNameLabel',
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? AppLocalizations.t('fieldRequired')
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneCtrl,
                              enabled: !_isLoading,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: InputDecoration(
                                labelText: AppLocalizations.t('phoneNumber'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: _exempt,
                              onChanged: (v) =>
                                  setState(() => _exempt = v ?? false),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                AppLocalizations.t('tankerExemptLabel'),
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _addFlat(society),
                                child: Text(AppLocalizations.t('addFlatBtn')),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (flats.isEmpty)
                        EmptyState(
                          icon: Icons.home_work_outlined,
                          title: AppLocalizations.t('emptyFlatsTitle'),
                          subtitle: AppLocalizations.t('emptyFlatsSub'),
                        )
                      else ...[
                        SectionHeader(
                          AppLocalizations.t('flatsResidentsTitle'),
                        ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: flats.isEmpty
                        ? null
                        : () => Navigator.pushReplacementNamed(
                            context,
                            resolvePostAuthRoute(context),
                          ),
                    child: Text(AppLocalizations.t('goToDashboard')),
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
