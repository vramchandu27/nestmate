import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../config/routing.dart';
import '../../models/role.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../services/phone_auth_service.dart';
import '../../utils/auth_field_decoration.dart';
import '../../utils/phone.dart';
import '../../widgets/loading_overlay.dart';
import 'otp_screen.dart';

/// NestMate - Admin Signup Screen
///
/// Creates the founding admin account for a brand-new building: name,
/// phone, password — no flat/roster involved, unlike resident signup.
/// There is only ever one admin per building (see
/// SocietyProvider.claimAdminIfUnbound); once created, this screen hands
/// off into block setup and then adding flats.
class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _submitted = false;
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    setState(() {
      _phoneError = null;
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();

    // Only one admin can exist per building — reject if someone else
    // already holds the seat. See SocietyProvider.canSignInAsAdmin.
    if (!context.read<SocietyProvider>().canSignInAsAdmin(phone)) {
      setState(() => _phoneError = AppLocalizations.t('adminAlreadyExists'));
      _formKey.currentState!.validate();
      return;
    }

    final name = _nameController.text.trim();

    setState(() => _isLoading = true);
    PhoneCodeResult? result;
    await withLoadingOverlay(context, () async {
      result = await PhoneAuthService().sendCode(phone: toE164Phone(phone));
      if (!mounted) return;
      // Keep the overlay up through whatever happens next — tearing it
      // down right after sendCode() succeeds would flash this signup
      // screen for a frame before the next screen actually appears. The
      // 'failed' case is handled below instead, after the overlay comes
      // down, since nothing navigates away on failure.
      switch (result!.status) {
        case PhoneCodeStatus.failed:
          return;
        case PhoneCodeStatus.autoVerified:
          await _completeAdminSignup(context, phone: phone, name: name);
        case PhoneCodeStatus.codeSent:
          Navigator.pushNamed(
            context,
            '/otp',
            arguments: OtpScreenArgs(
              phone: phone,
              verificationId: result!.verificationId!,
              resendToken: result!.resendToken,
              onVerified: (ctx) =>
                  _completeAdminSignup(ctx, phone: phone, name: name),
            ),
          );
          await awaitRouteTransition();
      }
    });
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

  /// Not using [completeSignIn] here: it derives the display name from the
  /// building, which has no name yet for a brand-new admin — use what they
  /// just typed on this form instead. Called only after real phone
  /// verification succeeds (either instantly via [PhoneCodeStatus.autoVerified]
  /// or from the OTP screen's [OtpScreenArgs.onVerified]).
  Future<void> _completeAdminSignup(
    BuildContext ctx, {
    required String phone,
    required String name,
  }) async {
    final society = ctx.read<SocietyProvider>();
    bool isRealAdmin;
    try {
      isRealAdmin = await society.claimAdminIfUnbound(phone);
    } catch (_) {
      // A failed write here (e.g. a Firestore rules rejection) must not
      // fail silently — the OTP screen that calls this has no other way
      // to tell the admin anything went wrong.
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('errorOccurred')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (!ctx.mounted) return;
    if (!isRealAdmin) {
      // The early canSignInAsAdmin check above is only best-effort (it
      // reads in-memory data that may not have loaded yet for a phone
      // nobody has seen before) — this is the real, authoritative result.
      // Someone else already holds the seat, so this signup must not
      // proceed as if it had succeeded.
      await FirebaseAuth.instance.signOut();
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('adminAlreadyExists')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    // Links a password credential to the phone-verified Firebase user, so
    // the same account can log back in with either OTP or the password
    // just chosen — non-fatal if it fails, since OTP login always works
    // regardless.
    try {
      await FirebaseAuth.instance.currentUser?.linkWithCredential(
        EmailAuthProvider.credential(
          email: passwordAuthEmailFor(phone),
          password: _passwordController.text,
        ),
      );
    } on FirebaseAuthException {
      // ignore
    }
    if (!ctx.mounted) return;
    ctx.read<AppProvider>().setUserInfo(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      communityId: society.building.name,
      role: UserRole.communityAdmin,
      userName: name,
      userPhone: phone,
    );
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t('accountCreatedSuccessfully')),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pushReplacementNamed(ctx, resolvePostAuthRoute(ctx));
    await awaitRouteTransition();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: _CircleDecor(
              color: AppTheme.primary.withValues(alpha: 0.04),
              size: 200,
            ),
          ),
          Positioned(
            bottom: 50,
            left: -30,
            child: _CircleDecor(
              color: AppTheme.accentTeal.withValues(alpha: 0.03),
              size: 150,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _HeaderButton(
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        Text(
                          AppLocalizations.t('createAdminAccount'),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.t('adminSignupSub'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textMedium,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
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
                                _InputLabel(label: AppLocalizations.t('name')),
                                TextFormField(
                                  controller: _nameController,
                                  enabled: !_isLoading,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: authFieldDecoration(
                                    hint: AppLocalizations.t('enterYourName'),
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? AppLocalizations.t('enterName')
                                      : null,
                                ),
                                const SizedBox(height: 20),

                                _InputLabel(
                                  label: AppLocalizations.t('phoneNumber'),
                                ),
                                TextFormField(
                                  controller: _phoneController,
                                  enabled: !_isLoading,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: authFieldDecoration(
                                    hint: '98765 43210',
                                    icon: Icons.phone_android_rounded,
                                  ),
                                  validator: (v) {
                                    if (_phoneError != null) {
                                      return _phoneError;
                                    }
                                    if (v == null || v.trim().isEmpty) {
                                      return AppLocalizations.t(
                                        'enterPhoneNumber',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                _InputLabel(
                                  label: AppLocalizations.t('password'),
                                ),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !_isLoading,
                                  obscureText: _obscurePassword,
                                  decoration: authFieldDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: AppTheme.textLight,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      tooltip: AppLocalizations.t(
                                        _obscurePassword
                                            ? 'showPassword'
                                            : 'hidePassword',
                                      ),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? AppLocalizations.t(
                                          'passwordMinimumLength',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 20),

                                _InputLabel(
                                  label: AppLocalizations.t('confirmPassword'),
                                ),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  enabled: !_isLoading,
                                  obscureText: _obscureConfirmPassword,
                                  decoration: authFieldDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_reset_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: AppTheme.textLight,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                      tooltip: AppLocalizations.t(
                                        _obscureConfirmPassword
                                            ? 'showPassword'
                                            : 'hidePassword',
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      v != _passwordController.text
                                      ? AppLocalizations.t('passwordMismatch')
                                      : null,
                                ),

                                const SizedBox(height: 24),

                                FormField<bool>(
                                  initialValue: _agreedToTerms,
                                  validator: (_) => _agreedToTerms
                                      ? null
                                      : AppLocalizations.t('agreeToTerms'),
                                  builder: (state) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: Checkbox(
                                                value: _agreedToTerms,
                                                onChanged: _isLoading
                                                    ? null
                                                    : (v) {
                                                        setState(
                                                          () => _agreedToTerms =
                                                              v ?? false,
                                                        );
                                                        state.didChange(v);
                                                      },
                                                activeColor: AppTheme.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(
                                                    () => _agreedToTerms =
                                                        !_agreedToTerms,
                                                  );
                                                  state.didChange(
                                                    _agreedToTerms,
                                                  );
                                                },
                                                child: Text(
                                                  AppLocalizations.t(
                                                    'agreeToTermsAndConditions',
                                                  ),
                                                  style: const TextStyle(
                                                    color: AppTheme.textMedium,
                                                    fontSize: 13,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (state.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 36,
                                              top: 6,
                                            ),
                                            child: Text(
                                              state.errorText!,
                                              style: const TextStyle(
                                                color: AppTheme.error,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),

                                const SizedBox(height: 32),

                                SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleSignup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 2,
                                      shadowColor: AppTheme.primary.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: Text(
                                      AppLocalizations.t('createAccount'),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.t('haveAccount'),
                                style: const TextStyle(
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                ),
                                child: Text(
                                  AppLocalizations.t('login'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
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

class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppTheme.textDark,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _HeaderButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textDark),
        onPressed: onPressed,
        tooltip: AppLocalizations.t('back'),
      ),
    );
  }
}

class _CircleDecor extends StatelessWidget {
  final Color color;
  final double size;
  const _CircleDecor({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
