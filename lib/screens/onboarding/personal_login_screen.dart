import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../models/role.dart';
import '../../providers/app_provider.dart';
import '../../services/phone_auth_service.dart';
import '../../utils/auth_field_decoration.dart';
import '../../utils/phone.dart';
import '../../widgets/loading_overlay.dart';
import 'otp_screen.dart';

/// A standalone entry point for someone who wants nothing but the personal
/// expense tracker — not a resident, not an admin, not tied to any
/// building or flat at all. Deliberately separate from [LoginScreen]'s
/// Resident/Admin tabs (and not modeled on the Committee link either):
/// just a phone number and a code, same real OTP flow as everywhere else
/// in the app, landing on `/personal-shell` once verified.
class PersonalLoginScreen extends StatefulWidget {
  const PersonalLoginScreen({super.key});

  @override
  State<PersonalLoginScreen> createState() => _PersonalLoginScreenState();
}

class _PersonalLoginScreenState extends State<PersonalLoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().setUserRole(UserRole.personal);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _phoneError = null;
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    setState(() => _isLoading = true);
    PhoneCodeResult? result;
    try {
      await withLoadingOverlay(context, () async {
        result = await PhoneAuthService().sendCode(phone: toE164Phone(phone));
        if (!mounted) return;
        switch (result!.status) {
          case PhoneCodeStatus.failed:
            return;
          case PhoneCodeStatus.autoVerified:
            final signedIn = await completeSignIn(context, phone: phone);
            if (!mounted) return;
            if (!signedIn) {
              await FirebaseAuth.instance.signOut();
              setState(
                () => _phoneError = AppLocalizations.t('errorOccurred'),
              );
              _formKey.currentState!.validate();
              return;
            }
            // Clears the whole stack, not just this screen: otherwise the
            // login screen stays underneath and the Android back button
            // from the signed-in shell lands the user back on it.
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/personal-shell',
              (_) => false,
            );
            // Keep the loading overlay up through the route transition —
            // without this it tears down the instant this closure returns,
            // flashing this screen again before the next one appears.
            await awaitRouteTransition();
          case PhoneCodeStatus.codeSent:
            Navigator.pushNamed(
              context,
              '/otp',
              arguments: OtpScreenArgs(
                phone: phone,
                verificationId: result!.verificationId!,
                resendToken: result!.resendToken,
              ),
            );
            await awaitRouteTransition();
        }
      });
    } catch (e) {
      debugPrint('PersonalLoginScreen._continue: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.t('errorOccurred'))));
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result?.status == PhoneCodeStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?.errorMessage ?? AppLocalizations.t('otpSendFailed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppTheme.textDark,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: AppLocalizations.t('back'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.t('personalLoginHeading'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.t('personalLoginSub'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textMedium,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.shadowLg,
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _submitted
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.t('phoneNumber'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneController,
                              enabled: !_isLoading,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              decoration: authFieldDecoration(
                                hint: '98765 43210',
                                icon: Icons.phone_android_rounded,
                              ),
                              validator: (v) {
                                if (_phoneError != null) return _phoneError;
                                if (v == null || v.trim().isEmpty) {
                                  return AppLocalizations.t('enterPhoneNumber');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _continue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                  shadowColor: AppTheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.t('continueBtn'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
