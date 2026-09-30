import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../models/flat.dart';
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
  // A second person in the same flat — a spouse, a parent, an adult child.
  // Optional: most flats register one number, and the fields only appear
  // once the admin asks for them.
  final _coNameCtrl = TextEditingController();
  final _coPhoneCtrl = TextEditingController();
  bool _addingCoResident = false;

  /// Set while editing an existing flat — the form holds every field a
  /// flat has, so it doubles as the editor rather than duplicating it.
  /// Null when adding a new flat.
  String? _editingFlatNumber;
  final _formKey = GlobalKey<FormState>();
  bool _exempt = false;
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _flatCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _coNameCtrl.dispose();
    _coPhoneCtrl.dispose();
    super.dispose();
  }

  void _startEditing(Flat f) {
    setState(() {
      _editingFlatNumber = f.flatNumber;
      _flatCtrl.text = f.flatNumber;
      _nameCtrl.text = f.residentName;
      // Stored in E.164 (+91…) but typed as ten digits, so strip it back
      // to what this field's own formatter will accept.
      _phoneCtrl.text = _tenDigits(f.phone);
      _exempt = f.tankerExempt;
      final co = f.coResidents.isEmpty ? null : f.coResidents.first;
      _addingCoResident = co != null;
      _coNameCtrl.text = co?.name ?? '';
      _coPhoneCtrl.text = co == null ? '' : _tenDigits(co.phone);
      _submitted = false;
    });
  }

  static String _tenDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  void _cancelEditing() {
    setState(() {
      _editingFlatNumber = null;
      _flatCtrl.clear();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _coNameCtrl.clear();
      _coPhoneCtrl.clear();
      _addingCoResident = false;
      _exempt = false;
      _submitted = false;
    });
  }

  Future<void> _confirmDelete(SocietyProvider society, Flat f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('deleteFlatTitle')),
        content: Text(
          '${AppLocalizations.t('flat')} ${f.flatNumber} · ${f.residentName}\n\n'
          '${AppLocalizations.t('deleteFlatBody')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await society.deleteFlat(f.flatNumber);
    if (_editingFlatNumber == f.flatNumber) _cancelEditing();
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
        coResidents: _coPhoneCtrl.text.trim().isEmpty
            ? const []
            : [
                CoResident(
                  name: _coNameCtrl.text.trim(),
                  phone: _coPhoneCtrl.text.trim(),
                ),
              ],
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
      _coNameCtrl.clear();
      _coPhoneCtrl.clear();
      _addingCoResident = false;
      _editingFlatNumber = null;
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
                            const SizedBox(height: 4),
                            // Hidden behind a tap: one number is the norm,
                            // and two always-visible extra fields would
                            // imply every flat needs them.
                            if (!_addingCoResident)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(
                                          () => _addingCoResident = true,
                                        ),
                                  icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    AppLocalizations.t('addAnotherPerson'),
                                  ),
                                ),
                              )
                            else ...[
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.t('secondPersonLabel'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.t('secondPersonHint'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textLight,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _coNameCtrl,
                                enabled: !_isLoading,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.t('name'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _coPhoneCtrl,
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
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(() {
                                          _addingCoResident = false;
                                          _coNameCtrl.clear();
                                          _coPhoneCtrl.clear();
                                        }),
                                  child: Text(AppLocalizations.t('remove')),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
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
                                child: Text(
                                  AppLocalizations.t(
                                    _editingFlatNumber == null
                                        ? 'addFlatBtn'
                                        : 'updateFlatBtn',
                                  ),
                                ),
                              ),
                            ),
                            if (_editingFlatNumber != null)
                              TextButton(
                                onPressed: _isLoading ? null : _cancelEditing,
                                child: Text(AppLocalizations.t('cancel')),
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
                            // Tap to load this flat into the form above.
                            // Before this there was no way to correct a
                            // mistyped phone number at all — the only
                            // options were leaving it wrong or rebuilding
                            // the flat from scratch.
                            onTap: _isLoading ? null : () => _startEditing(f),
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
                                IconButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _confirmDelete(society, f),
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: AppTheme.textLight,
                                  ),
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
