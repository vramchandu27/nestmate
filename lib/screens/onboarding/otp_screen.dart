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
import '../../utils/phone.dart';
import '../../widgets/loading_overlay.dart';

/// The phone number and the Firebase verification session for it — set by
/// whoever sent the real SMS code (currently only [LoginScreen]'s OTP
/// path) and passed as this route's arguments.
class OtpScreenArgs {
  const OtpScreenArgs({
    required this.phone,
    required this.verificationId,
    this.resendToken,
    this.onVerified,
  });

  /// The raw phone number as the user typed it (not E.164) — this is what
  /// the rest of the app's admin/resident matching already expects.
  final String phone;
  final String verificationId;
  final int? resendToken;

  /// Runs instead of the default "[completeSignIn] then navigate to
  /// [resolvePostAuthRoute]" behavior once the code is confirmed — used by
  /// flows (admin/resident signup) that need to do something extra first,
  /// like claiming a flat or the admin seat with data typed on the signup
  /// form before this screen ever existed.
  final Future<void> Function(BuildContext context)? onVerified;
}

/// NestMate - OTP Verification Screen
///
/// High-trust authentication screen with focused OTP input and premium styling.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _phoneAuth = PhoneAuthService();
  bool _isLoading = false;
  int _resendCountdown = 30;
  String? _otpError;

  /// Set once a verified phone number turned out to have no matching
  /// account — read by the back button so it can tell [LoginScreen] to
  /// clear the phone field it's returning to, rather than leaving a number
  /// there that's already known not to work.
  bool _phoneNotRegistered = false;

  late OtpScreenArgs _args;
  late String _verificationId;
  int? _resendToken;
  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      _args = ModalRoute.of(context)!.settings.arguments as OtpScreenArgs;
      _verificationId = _args.verificationId;
      _resendToken = _args.resendToken;
      _argsLoaded = true;
    }
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      }
    });
  }

  void _handleOtpInput(String value, int index) {
    if (_otpError != null) setState(() => _otpError = null);
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    } else if (value.isEmpty && index > 0) {
      // Handle backspace
      _otpControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  // onChanged only fires when the text actually changes, so backspacing on
  // a box that's already empty (e.g. right after auto-advancing past a
  // just-typed digit) never reaches _handleOtpInput above — nothing to
  // delete means no change event, so focus was getting stuck. This listens
  // for the raw backspace key press instead, which fires regardless.
  void _handleBackspaceOnEmpty(int index) {
    if (index > 0) {
      _otpControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _otpError = AppLocalizations.t('invalidOtp'));
      return;
    }

    final phone = _args.phone;

    // Only one admin can exist per building — reject any other phone
    // trying to claim the seat once it's bound. See SocietyProvider.
    if (context.read<AppProvider>().userRole.isAdmin &&
        !context.read<SocietyProvider>().canSignInAsAdmin(phone)) {
      setState(() => _otpError = AppLocalizations.t('adminAlreadyExists'));
      _clearOtpFields();
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    String? errorMessage;
    var notRegistered = false;
    await withLoadingOverlay(context, () async {
      try {
        await _phoneAuth.confirmCode(
          verificationId: _verificationId,
          smsCode: otp,
        );
      } on FirebaseAuthException catch (e) {
        errorMessage = e.code == 'invalid-verification-code'
            ? AppLocalizations.t('invalidOtp')
            : (e.message ?? AppLocalizations.t('invalidOtp'));
        return;
      } on TimeoutException {
        errorMessage = AppLocalizations.t('errorOccurred');
        return;
      }
      if (!mounted) return;
      // Keep the loading overlay up through sign-in completion and the
      // navigation it triggers too — tearing it down right after
      // confirmCode() succeeds would flash this OTP screen for a frame
      // before the next screen actually appears.
      if (_args.onVerified != null) {
        await _args.onVerified!(context);
        return;
      }
      final signedIn = await completeSignIn(context, phone: phone);
      if (!mounted) return;
      if (!signedIn) {
        // A verified phone number with no matching flat/admin — never
        // fall through to some other flat's data. Undo the Firebase sign-in
        // so no dangling session is left behind, and surface a real error.
        await FirebaseAuth.instance.signOut();
        errorMessage = AppLocalizations.t('phoneNotRegistered');
        notRegistered = true;
        return;
      }
      Navigator.pushReplacementNamed(context, resolvePostAuthRoute(context));
      await awaitRouteTransition();
    });
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage != null) {
      setState(() {
        _otpError = errorMessage;
        if (notRegistered) _phoneNotRegistered = true;
      });
      _clearOtpFields();
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _resendCountdown = 30);
    _clearOtpFields();
    _startResendCountdown();

    final result = await _phoneAuth.sendCode(
      phone: toE164Phone(_args.phone),
      resendToken: _resendToken,
    );
    if (!mounted) return;

    switch (result.status) {
      case PhoneCodeStatus.codeSent:
        _verificationId = result.verificationId!;
        _resendToken = result.resendToken;
      case PhoneCodeStatus.failed:
        setState(
          () => _otpError =
              result.errorMessage ?? AppLocalizations.t('otpSendFailed'),
        );
      case PhoneCodeStatus.autoVerified:
        // Silently verified on this device already — sign in directly.
        if (_args.onVerified != null) {
          await _args.onVerified!(context);
          return;
        }
        final signedIn = await completeSignIn(context, phone: _args.phone);
        if (!mounted) return;
        if (!signedIn) {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _otpError = AppLocalizations.t('phoneNotRegistered');
            _phoneNotRegistered = true;
          });
          return;
        }
        Navigator.pushReplacementNamed(context, resolvePostAuthRoute(context));
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
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
            left: -50,
            child: _CircleDecor(
              color: AppTheme.primary.withValues(alpha: 0.04),
              size: 200,
            ),
          ),
          Positioned(
            bottom: 100,
            right: -30,
            child: _CircleDecor(
              color: AppTheme.accentTeal.withValues(alpha: 0.3),
              size: 150,
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
                        onPressed: () =>
                            Navigator.pop(context, _phoneNotRegistered),
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

                        // Hero Text
                        Text(
                          AppLocalizations.t('enterOtp'),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.t('otpSentMessage'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textMedium,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Form Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: AppTheme.shadowLg,
                          ),
                          child: Column(
                            children: [
                              // OTP Input Fields — Expanded so 6 boxes
                              // always fit, even on the narrowest phones.
                              Row(
                                children: List.generate(
                                  6,
                                  (index) => Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: index == 0 ? 0 : 4,
                                      ),
                                      child: _OtpInputField(
                                        controller: _otpControllers[index],
                                        focusNode: _focusNodes[index],
                                        isLoading: _isLoading,
                                        hasError: _otpError != null,
                                        onChanged: (value) =>
                                            _handleOtpInput(value, index),
                                        onBackspaceOnEmpty: () =>
                                            _handleBackspaceOnEmpty(index),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_otpError != null) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _otpError!,
                                    style: const TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 40),

                              // Verify button
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOtp,
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
                                    AppLocalizations.t('verify'),
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

                        const SizedBox(height: 32),

                        // Resend OTP Section
                        Center(
                          child: Column(
                            children: [
                              if (_resendCountdown > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${AppLocalizations.t('resendOtpIn')} $_resendCountdown ${AppLocalizations.t('seconds')}',
                                    style: const TextStyle(
                                      color: AppTheme.textMedium,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: _resendOtp,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    AppLocalizations.t('resendOtp'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                  ),
                                ),
                            ],
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

class _OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspaceOnEmpty;

  const _OtpInputField({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.hasError,
    required this.onChanged,
    required this.onBackspaceOnEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? AppTheme.error : AppTheme.primary;
    // A plain ancestor Focus (its own internal node, not [focusNode])
    // catches the backspace key event as it bubbles up from the TextField
    // once EditableText itself ignores it (nothing to delete). Sharing
    // [focusNode] directly with a KeyboardListener here instead causes a
    // "Tried to make a child into a parent of itself" crash — two widgets
    // both trying to attach the same node as their own focus scope.
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            controller.text.isEmpty) {
          onBackspaceOnEmpty();
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !isLoading,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        // Tapping into a box that already has a digit selects it, so the
        // next keystroke replaces it instead of being rejected by the
        // length-1 formatter (which otherwise makes editing a single digit
        // in the middle require clearing the whole code and retyping it).
        onTap: () => controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppTheme.textDark,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppTheme.background.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: hasError
                ? BorderSide(color: AppTheme.error, width: 1.5)
                : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: hasError
                ? BorderSide(color: AppTheme.error, width: 1.5)
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 2),
          ),
        ),
        onChanged: onChanged,
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
