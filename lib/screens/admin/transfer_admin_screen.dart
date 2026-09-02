import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';

/// Hands the sole admin seat to a different phone number. There is only
/// ever one admin per building (see SocietyProvider.transferAdmin) — this
/// is the only way to reassign it besides the seat being unclaimed.
class TransferAdminScreen extends StatefulWidget {
  const TransferAdminScreen({super.key});

  @override
  State<TransferAdminScreen> createState() => _TransferAdminScreenState();
}

class _TransferAdminScreenState extends State<TransferAdminScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _confirmTransfer() {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    final newPhone = _phoneCtrl.text.trim();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('transferAdminConfirmTitle')),
        content: Text(AppLocalizations.t('transferAdminConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              _performTransfer(newPhone);
            },
            child: Text(AppLocalizations.t('transferAdminBtn')),
          ),
        ],
      ),
    );
  }

  Future<void> _performTransfer(String newPhone) async {
    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => context.read<SocietyProvider>().transferAdmin(newPhone),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    context.read<AppProvider>().clearUserInfo();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t('transferAdminSuccess')),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
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
              ScreenHeader(title: AppLocalizations.t('transferAdminTitle')),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Center(
                        child: Icon(
                          Icons.swap_horizontal_circle_rounded,
                          size: 46,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.t('transferAdminSub'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textMedium,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (building.adminPhone.isNotEmpty)
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.t('admin'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                    Text(
                                      building.adminPhone,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.t('newAdminPhoneLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneCtrl,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          hintText: '98765 43210',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.t('fieldRequired')
                            : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _confirmTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                        ),
                        child: Text(AppLocalizations.t('transferAdminBtn')),
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
