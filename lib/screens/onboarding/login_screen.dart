import 'dart:async';

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

/// NestMate - Login Screen
///
/// A premium authentication experience with layered depth and clear focus.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _flatNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isAdminMode = false;
  bool _submitted = false;
  String? _phoneError;
  String? _flatNumberError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    // Arms the resident path by default; the toggle re-arms this on tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().setUserRole(UserRole.resident);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _flatNumberController.dispose();
    super.dispose();
  }

  void _setRoleMode(bool admin) {
    setState(() {
      _isAdminMode = admin;
      // Resident and admin are different accounts — carrying a typed
      // phone/password over to the other tab would just cause confusing
      // wrong-role login attempts.
      _phoneController.clear();
      _passwordController.clear();
      _flatNumberController.clear();
      _phoneError = null;
      _flatNumberError = null;
      _passwordError = null;
      _submitted = false;
      // Switching modes changes which fields exist (resident mode adds a
      // Flat Number field admin mode doesn't have) — without this, a
      // still-mounted field's cached validation error can visually land on
      // the wrong field once the list of fields reshapes.
      _formKey.currentState?.reset();
    });
    context.read<AppProvider>().setUserRole(
      admin ? UserRole.communityAdmin : UserRole.resident,
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _phoneError = null;
      _flatNumberError = null;
      _passwordError = null;
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final flatNumber = _flatNumberController.text.trim();

    // Only one admin can exist per building — reject any other phone
    // trying to claim the seat once it's bound. See SocietyProvider.
    if (_isAdminMode &&
        !context.read<SocietyProvider>().canSignInAsAdmin(phone)) {
      setState(() => _phoneError = AppLocalizations.t('adminAlreadyExists'));
      _formKey.currentState!.validate();
      return;
    }

    setState(() => _isLoading = true);

    if (_isPasswordMode) {
      // checkFlatClaim reads Firestore, and every read in this app requires
      // being signed in already — running it before the real sign-in
      // below throws permission-denied once the device has no lingering
      // session (e.g. right after a real logout). So the password check
      // has to happen FIRST, then checkFlatClaim as a second guard on top
      // of an already-authenticated session.
      String? flatClaimErrorKey;
      // Null unless the Admin tab rejected this account — then it holds
      // which of the two admin rejections happened (see adminSignInErrorKey).
      String? notAdmin;
      try {
        await withLoadingOverlay(context, () async {
          // Real password check — signs into the Firebase credential
          // linked at signup (see SignupScreen/AdminSignupScreen), so a
          // wrong password is actually rejected instead of any password
          // working as long as the phone/flat matched.
          // Timeout guards against exactly the bug this app hit already —
          // an unbounded await on a flaky/slow connection leaving the
          // loading overlay up forever with nothing tappable underneath.
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: passwordAuthEmailFor(phone),
                password: _passwordController.text,
              )
              .timeout(const Duration(seconds: 15));
          if (!mounted) return;

          // Resident password login has no OTP step, so this is the only
          // guard that the flat actually belongs to this phone — same
          // roster check signup uses. See SocietyProvider.checkFlatClaim.
          if (!_isAdminMode) {
            flatClaimErrorKey = await context
                .read<SocietyProvider>()
                .checkFlatClaim(flatNumber: flatNumber, phone: phone);
            if (!mounted) return;
            if (flatClaimErrorKey != null) {
              // The password matched, but the typed flat number doesn't —
              // don't leave a signed-in session behind for a login
              // attempt that didn't actually succeed.
              await FirebaseAuth.instance.signOut();
              return;
            }
          }

          // Keep the overlay up through sign-in completion and the
          // navigation it triggers too — tearing it down right after the
          // password check succeeds would flash this login screen for a
          // frame before the next screen actually appears.
          final signedIn = await completeSignIn(
            context,
            phone: phone,
            flatNumberOverride: _isAdminMode ? null : flatNumber,
          );
          if (!mounted) return;
          if (!signedIn) {
            // Correct password, correct account — but for the Admin tab
            // specifically, that account isn't actually the bound admin
            // (e.g. a resident's own valid credentials used on the wrong
            // tab). Don't leave a signed-in session behind for a login
            // attempt that didn't actually grant the access it claimed to.
            // Work out which rejection this is before signing out — the
            // sign-out clears the resolved society that distinguishes them.
            notAdmin = adminSignInErrorKey(context);
            await FirebaseAuth.instance.signOut();
            return;
          }
          // Clears the stack so the back button from a signed-in dashboard
          // can't land the user back on Welcome/Login.
          Navigator.pushNamedAndRemoveUntil(
            context,
            resolvePostAuthRoute(context),
            (_) => false,
          );
          await awaitRouteTransition();
        });
      } on FirebaseAuthException {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _passwordError = AppLocalizations.t('incorrectPassword');
        });
        _formKey.currentState!.validate();
        return;
      } on TimeoutException {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _phoneError = AppLocalizations.t('errorOccurred');
        });
        _formKey.currentState!.validate();
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (flatClaimErrorKey != null) {
        setState(() {
          if (flatClaimErrorKey == 'flatNotFound') {
            _flatNumberError = AppLocalizations.t(flatClaimErrorKey!);
          } else {
            _phoneError = AppLocalizations.t(flatClaimErrorKey!);
          }
        });
        _formKey.currentState!.validate();
      } else if (notAdmin != null) {
        setState(() => _phoneError = AppLocalizations.t(notAdmin!));
        _formKey.currentState!.validate();
      }
      return;
    }

    await _sendOtpAndNavigate(phone);
  }

  /// Sends a real Firebase SMS code, then either lands on the OTP screen
  /// (normal case), signs in directly (some Android devices verify
  /// silently without a code), or shows the send failure.
  Future<void> _sendOtpAndNavigate(String phone) async {
    setState(() => _isLoading = true);
    PhoneCodeResult? result;
    try {
      await withLoadingOverlay(context, () async {
        result = await PhoneAuthService().sendCode(phone: toE164Phone(phone));
        if (!mounted) return;
        // Keep the overlay up through whatever happens next — sign-in
        // completion + navigation, or pushing the OTP screen — tearing it
        // down right after sendCode() succeeds would flash this login
        // screen for a frame before the next screen actually appears. The
        // 'failed' case is handled below instead, after the overlay comes
        // down, since nothing navigates away on failure.
        switch (result!.status) {
          case PhoneCodeStatus.failed:
            return;
          case PhoneCodeStatus.autoVerified:
            final signedIn = await completeSignIn(context, phone: phone);
            if (!mounted) return;
            if (!signedIn) {
              // A verified phone number with no matching flat/admin — never
              // fall through to some other flat's data. Undo the sign-in and
              // surface a real error instead of silently landing somewhere.
              // Resolve the admin wording before the sign-out clears what it
              // reads (see adminSignInErrorKey).
              final errorKey = _isAdminMode
                  ? adminSignInErrorKey(context)
                  : 'phoneNotRegistered';
              await FirebaseAuth.instance.signOut();
              setState(() => _phoneError = AppLocalizations.t(errorKey));
              _formKey.currentState!.validate();
              return;
            }
            Navigator.pushNamedAndRemoveUntil(
              context,
              resolvePostAuthRoute(context),
              (_) => false,
            );
            await awaitRouteTransition();
          case PhoneCodeStatus.codeSent:
            // Not awaited here — that would keep the loading overlay up for
            // the OTP screen's entire lifetime instead of just the
            // transition. The result (whether the OTP screen's back arrow
            // was tapped after a "no account found" error) is only needed
            // later, once the user is actually back on this screen.
            // Not typed <bool> here — '/otp' is registered through
            // MaterialApp's plain `routes:` map, which always resolves to
            // an untyped MaterialPageRoute<dynamic>, not a Route<bool>.
            // Requesting <bool> makes Flutter type-check the resolved
            // route against that generic, which always fails with a
            // runtime TypeError ("MaterialPageRoute<dynamic> is not a
            // subtype of Route<bool?>") — every OTP-mode login hit this,
            // every single time. The `== true` comparison below works
            // fine on the untyped result without needing a cast.
            Navigator.pushNamed(
              context,
              '/otp',
              arguments: OtpScreenArgs(
                phone: phone,
                verificationId: result!.verificationId!,
                resendToken: result!.resendToken,
              ),
            ).then((shouldClearPhone) {
              if (shouldClearPhone == true && mounted) {
                _phoneController.clear();
              }
            });
            await awaitRouteTransition();
        }
      });
    } catch (e) {
      // Whatever unexpectedly went wrong here — a bad argument, a
      // navigation failure, anything not already handled above — must
      // never leave the button stuck disabled forever with no way
      // forward. Always land back in a usable state with a real error.
      debugPrint('LoginScreen._sendOtpAndNavigate: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('errorOccurred'))),
      );
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
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -50,
            right: -50,
            child: _CircleDecor(
              color: AppTheme.primary.withValues(alpha: 0.04),
              size: 200,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Header
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
                        const SizedBox(height: 12),

                        // Brand mark — continuity with the Welcome screen.
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Text(
                                '🏡',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.t('welcome'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Hero Text — stays fixed; only the subtitle reflects the mode.
                        Text(
                          AppLocalizations.t('signInHeading'),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isAdminMode
                              ? AppLocalizations.t('adminLoginSub')
                              : AppLocalizations.t('residentLoginSub'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textMedium,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Form Container — role tabs docked to the top edge.
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppTheme.shadowLg,
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  4,
                                ),
                                child: _CardTabs(
                                  isAdminMode: _isAdminMode,
                                  onChanged: _setRoleMode,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  24,
                                  24,
                                ),
                                child: Form(
                                  key: _formKey,
                                  autovalidateMode: _submitted
                                      ? AutovalidateMode.onUserInteraction
                                      : AutovalidateMode.disabled,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!_isAdminMode && _isPasswordMode) ...[
                                        _InputLabel(
                                          label: AppLocalizations.t(
                                            'flatNumber',
                                          ),
                                        ),
                                        TextFormField(
                                          key: const ValueKey(
                                            'loginFlatNumberField',
                                          ),
                                          controller: _flatNumberController,
                                          enabled: !_isLoading,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          decoration: authFieldDecoration(
                                            hint: '101',
                                            icon: Icons.apartment_rounded,
                                          ),
                                          validator: (v) {
                                            if (_flatNumberError != null) {
                                              return _flatNumberError;
                                            }
                                            if (v == null ||
                                                v.trim().isEmpty) {
                                              return AppLocalizations.t(
                                                'enterFlatNumber',
                                              );
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                      _InputLabel(
                                        label: AppLocalizations.t(
                                          'phoneNumber',
                                        ),
                                      ),
                                      TextFormField(
                                        key: const ValueKey(
                                          'loginPhoneField',
                                        ),
                                        controller: _phoneController,
                                        enabled: !_isLoading,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
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

                                      if (_isPasswordMode) ...[
                                        const SizedBox(height: 20),
                                        _InputLabel(
                                          label: AppLocalizations.t('password'),
                                        ),
                                        TextFormField(
                                          key: const ValueKey(
                                            'loginPasswordField',
                                          ),
                                          controller: _passwordController,
                                          enabled: !_isLoading,
                                          obscureText: _obscurePassword,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          decoration: authFieldDecoration(
                                            hint: '••••••••',
                                            icon: Icons.lock_outline_rounded,
                                            suffix: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                          .visibility_off_outlined
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
                                          validator: (v) {
                                            if (_passwordError != null) {
                                              return _passwordError;
                                            }
                                            if (v == null || v.isEmpty) {
                                              return AppLocalizations.t(
                                                'enterPassword',
                                              );
                                            }
                                            return null;
                                          },
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () {
                                                    final phone =
                                                        _phoneController.text
                                                            .trim();
                                                    if (phone.isEmpty) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            AppLocalizations.t(
                                                              'enterPhoneNumber',
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    _sendOtpAndNavigate(phone);
                                                  },
                                            child: Text(
                                              AppLocalizations.t(
                                                'forgotPassword',
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 28),

                                      // Primary Action
                                      SizedBox(
                                        width: double.infinity,
                                        height: 58,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 2,
                                            shadowColor: AppTheme.primary
                                                .withValues(alpha: 0.4),
                                          ),
                                          child: Text(
                                            AppLocalizations.t('login'),
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
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Secondary Options
                        _AuthSwitchButton(
                          isPasswordMode: _isPasswordMode,
                          onPressed: () => setState(() {
                            _isPasswordMode = !_isPasswordMode;
                            _passwordController.clear();
                          }),
                        ),

                        const SizedBox(height: 24),

                        // Signup footer
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.t('noAccount'),
                                style: const TextStyle(
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  _isAdminMode ? '/admin-signup' : '/signup',
                                ),
                                child: Text(
                                  AppLocalizations.t('createAccount'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (context
                            .watch<SocietyProvider>()
                            .building
                            .committeeEnabled)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                context.read<AppProvider>().setUserRole(
                                  UserRole.committee,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.t(
                                        'continueAsCommitteeLink',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                AppLocalizations.t('continueAsCommitteeLink'),
                                style: const TextStyle(
                                  color: AppTheme.textMedium,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
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

class _CardTabs extends StatelessWidget {
  final bool isAdminMode;
  final ValueChanged<bool> onChanged;

  const _CardTabs({required this.isAdminMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sliding indicator — physically moves between the two sides.
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isAdminMode
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _RoleTab(
                  icon: Icons.person_rounded,
                  label: AppLocalizations.t('resident'),
                  selected: !isAdminMode,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _RoleTab(
                  icon: Icons.admin_panel_settings_rounded,
                  label: AppLocalizations.t('admin'),
                  selected: isAdminMode,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          color: selected ? Colors.white : AppTheme.textLight,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                icon,
                key: ValueKey(selected),
                size: 17,
                color: selected ? Colors.white : AppTheme.textLight,
              ),
            ),
            const SizedBox(width: 7),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _AuthSwitchButton extends StatelessWidget {
  final bool isPasswordMode;
  final VoidCallback onPressed;

  const _AuthSwitchButton({
    required this.isPasswordMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPasswordMode
                    ? Icons.textsms_outlined
                    : Icons.lock_open_rounded,
                size: 17,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isPasswordMode
                    ? AppLocalizations.t('loginWithOtp')
                    : AppLocalizations.t('loginWithPassword'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
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
