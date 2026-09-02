import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';
import 'transfer_admin_screen.dart';

/// Admin's own account screen: editable display name, a read-only view of
/// the building/phone they're tied to, language, a link to hand off the
/// admin seat, and sign out. There's no full "edit block" form here —
/// that's [BlockSetupScreen]'s job; this is just the admin's own identity.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final TextEditingController _nameCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final building = context.read<SocietyProvider>().building;
    _nameCtrl = TextEditingController(text: app.userName ?? building.adminName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => context.read<SocietyProvider>().updateAdminName(name),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.read<AppProvider>().updateUserName(name);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t('successfullySaved')),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              performLogout(context);
            },
            child: Text(AppLocalizations.t('logout')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final building = context.watch<SocietyProvider>().building;
    final app = context.watch<AppProvider>();
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : building.adminName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('navProfile')),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Center(
                        child: AvatarPicker(
                          photoUrl: app.userPhotoUrl,
                          initial: initial,
                          onPicked: (file) => updateProfilePhoto(context, file),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        AppLocalizations.t('yourNameInCharge'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.t('fieldRequired')
                            : null,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          child: Text(AppLocalizations.t('save')),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _InfoRow(
                        icon: Icons.apartment_rounded,
                        label: AppLocalizations.t('blockNameLabel'),
                        value: building.name,
                        photoUrl: building.photoUrl,
                      ),
                      _InfoRow(
                        icon: Icons.phone_rounded,
                        label: AppLocalizations.t('phoneNumber'),
                        value: app.userPhone ?? building.adminPhone,
                      ),
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
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
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransferAdminScreen(),
                          ),
                        ),
                        child: Text(AppLocalizations.t('transferAdminBtn')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _confirmLogout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                        ),
                        child: Text(AppLocalizations.t('logout')),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.photoUrl,
  });
  final IconData icon;
  final String label;
  final String value;

  /// When set, shows this photo instead of the plain [icon] — used for the
  /// building name row once a real cover photo has been uploaded.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: photoUrl != null
                ? Image.network(
                    photoUrl!,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    cacheWidth: 120,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 38,
                        height: 38,
                        color: AppTheme.accentBlue,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 38,
                      color: AppTheme.accentBlue,
                      child: Icon(icon, color: AppTheme.primary, size: 18),
                    ),
                  )
                : Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: AppTheme.accentBlue),
                    child: Icon(icon, color: AppTheme.primary, size: 18),
                  ),
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
