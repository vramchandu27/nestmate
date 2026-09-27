import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../providers/society_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/whatsapp.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/photo_picker_field.dart';
import '../../widgets/screen_header.dart';

/// Create-or-edit screen for the building's setup: name, admin name,
/// collector name, UPI collection id, cover photo, water-metering and
/// committee toggles. First-run (no block yet) leads onward into the
/// setup flow; editing an existing block just saves and returns.
class BlockSetupScreen extends StatefulWidget {
  const BlockSetupScreen({super.key});

  @override
  State<BlockSetupScreen> createState() => _BlockSetupScreenState();
}

class _BlockSetupScreenState extends State<BlockSetupScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _adminNameCtrl;
  late final TextEditingController _collectorNameCtrl;
  late final TextEditingController _upiCtrl;
  File? _photoFile;
  // True if a photo was already saved when this screen opened.
  late bool _alreadyHasPhoto;
  // True only if the user explicitly tapped "remove" this session —
  // distinct from _photoFile being null because nothing was ever touched.
  bool _photoRemoved = false;
  late bool _waterMetered;
  late bool _committeeEnabled;
  late bool _wasAlreadySetUp;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final building = context.read<SocietyProvider>().building;
    _wasAlreadySetUp = building.setupComplete;
    _nameCtrl = TextEditingController(text: building.name);
    _adminNameCtrl = TextEditingController(text: building.adminName);
    _collectorNameCtrl = TextEditingController(text: building.collectorName);
    _upiCtrl = TextEditingController(text: building.upiId);
    _alreadyHasPhoto = building.photoAdded;
    _waterMetered = building.waterMetered;
    _committeeEnabled = building.committeeEnabled;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _adminNameCtrl.dispose();
    _collectorNameCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  /// Warns — never blocks — when a society by this name already exists, so
  /// the second person from one building doesn't quietly create a duplicate
  /// that splits their residents. Returns whether to go ahead with setup.
  /// Only on first-time setup: re-editing your own society isn't a clash.
  Future<bool> _confirmNotDuplicate(SocietyProvider society) async {
    if (_wasAlreadySetUp) return true;
    final exists = await society.societyNameExists(_nameCtrl.text.trim());
    if (!exists || !mounted) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('duplicateSocietyTitle')),
        content: Text(AppLocalizations.t('duplicateSocietyBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('goBack')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('createAnyway')),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final society = context.read<SocietyProvider>();
    if (!await _confirmNotDuplicate(society)) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    var photoFailed = false;
    await withLoadingOverlay(context, () async {
      final photo = _photoFile;
      String? finalPhotoUrl;
      bool finalPhotoAdded;
      if (photo != null) {
        // A failed photo upload shouldn't block setup itself — this is the
        // screen a brand-new admin can't get past, so degrade gracefully
        // (keep whatever was already saved) instead of aborting the whole
        // thing.
        try {
          finalPhotoUrl = await StorageService().uploadPhoto(
            basePath: 'buildings/${society.buildingId}/cover',
            file: photo,
          );
          finalPhotoAdded = true;
        } catch (_) {
          photoFailed = true;
          finalPhotoUrl = _alreadyHasPhoto ? society.building.photoUrl : null;
          finalPhotoAdded = _alreadyHasPhoto;
        }
      } else if (_photoRemoved) {
        finalPhotoUrl = null;
        finalPhotoAdded = false;
      } else {
        finalPhotoUrl = society.building.photoUrl;
        finalPhotoAdded = _alreadyHasPhoto;
      }
      await society.completeBlockSetup(
        name: _nameCtrl.text.trim(),
        adminName: _adminNameCtrl.text.trim(),
        collectorName: _collectorNameCtrl.text.trim(),
        upiId: _upiCtrl.text.trim(),
        photoAdded: finalPhotoAdded,
        photoUrl: finalPhotoUrl,
        waterMetered: _waterMetered,
        committeeEnabled: _committeeEnabled,
      );
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (photoFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('errorOccurred')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    if (_wasAlreadySetUp) {
      Navigator.pop(context);
    } else {
      // The join code is minted by completeBlockSetup, so this is the first
      // moment it exists — and until now it was never shown here at all,
      // leaving brand-new admins with no idea their residents needed a code
      // or where to find it. Surface it before moving on.
      await _showJoinCode(society.building.joinCode);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, resolvePostAuthRoute(context));
    }
  }

  Future<void> _showJoinCode(String code) async {
    if (code.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('societyReadyTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.t('societyReadySub'),
              style: const TextStyle(color: AppTheme.textMedium, height: 1.45),
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _copyCode(code),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await sendTextViaWhatsApp(
                AppLocalizations.t(
                  'joinCodeShareMessage',
                ).replaceFirst('%s', code),
              );
            },
            child: Text(AppLocalizations.t('shareWithResidents')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('done')),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t('joinCodeCopied')),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final building = context.watch<SocietyProvider>().building;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (_wasAlreadySetUp)
                ScreenHeader(
                  title: AppLocalizations.t(
                    'associationRow',
                    defaultValue: 'Block',
                  ),
                ),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        AppLocalizations.t('newBlockTitle'),
                        style: AppTheme.displayStyle(
                          context,
                          size: 24,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.t('newBlockSub'),
                        style: const TextStyle(
                          color: AppTheme.textMedium,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_wasAlreadySetUp && building.joinCode.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.qr_code_rounded,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.t('joinCodeLabel'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                    Text(
                                      building.joinCode,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      PhotoPickerField(
                        label: AppLocalizations.t('addBuildingPhoto'),
                        file: _photoFile,
                        existingUrl: building.photoUrl,
                        height: 120,
                        placeholderGradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                        ),
                        placeholderIconColor: Colors.white,
                        placeholderTextColor: Colors.white,
                        onChanged: (f) => setState(() {
                          _photoFile = f;
                          if (f == null) _photoRemoved = true;
                        }),
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        label: AppLocalizations.t('blockNameLabel'),
                        controller: _nameCtrl,
                        enabled: !_isLoading,
                        required: true,
                        capitalizeWords: true,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: AppLocalizations.t('yourNameInCharge'),
                        controller: _adminNameCtrl,
                        enabled: !_isLoading,
                        capitalizeWords: true,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: AppLocalizations.t('collectorNameLabel'),
                        controller: _collectorNameCtrl,
                        enabled: !_isLoading,
                        capitalizeWords: true,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: AppLocalizations.t('upiIdLabel'),
                        controller: _upiCtrl,
                        enabled: !_isLoading,
                        required: true,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _waterMetered,
                        onChanged: (v) =>
                            setState(() => _waterMetered = v ?? true),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          AppLocalizations.t('waterMeteredLabel'),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                      CheckboxListTile(
                        value: _committeeEnabled,
                        onChanged: (v) =>
                            setState(() => _committeeEnabled = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          AppLocalizations.t('committeeEnabledLabel'),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(AppLocalizations.t('createBlockBtn')),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.required = false,
    this.capitalizeWords = false,
  });
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool required;
  final bool capitalizeWords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          textCapitalization: capitalizeWords
              ? TextCapitalization.words
              : TextCapitalization.none,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? AppLocalizations.t('fieldRequired')
                    : null
              : null,
        ),
      ],
    );
  }
}
