import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

enum PhoneCodeStatus { codeSent, autoVerified, failed }

/// Outcome of [PhoneAuthService.sendCode] — exactly one of "an SMS went
/// out" (codeSent), "this device verified silently, already signed in"
/// (autoVerified, common on Android), or "sending failed" (failed).
class PhoneCodeResult {
  PhoneCodeResult.codeSent(this.verificationId, this.resendToken)
    : status = PhoneCodeStatus.codeSent,
      errorMessage = null;

  PhoneCodeResult.autoVerified()
    : status = PhoneCodeStatus.autoVerified,
      verificationId = null,
      resendToken = null,
      errorMessage = null;

  PhoneCodeResult.failed(this.errorMessage)
    : status = PhoneCodeStatus.failed,
      verificationId = null,
      resendToken = null;

  final PhoneCodeStatus status;
  final String? verificationId;
  final int? resendToken;
  final String? errorMessage;
}

/// Thin wrapper around real Firebase Phone Auth — sends and verifies SMS
/// codes for the login screen's OTP flow.
class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sends a real SMS code to [phone] (E.164, e.g. "+919876543210"). Pass
  /// [resendToken] (from a previous [PhoneCodeResult.codeSent]) to resend
  /// to the same number without waiting out Firebase's own cooldown twice.
  Future<PhoneCodeResult> sendCode({required String phone, int? resendToken}) {
    final completer = Completer<PhoneCodeResult>();

    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Some Android devices verify silently without the user typing
        // anything — sign in immediately rather than waiting for a code.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(PhoneCodeResult.autoVerified());
        } catch (e) {
          if (!completer.isCompleted) {
            completer.complete(PhoneCodeResult.failed(_messageFor(e)));
          }
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.complete(PhoneCodeResult.failed(_messageFor(e)));
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(PhoneCodeResult.codeSent(verificationId, resendToken));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    // verifyPhoneNumber's own `timeout` only bounds the auto-retrieval
    // phase after a code has already been sent — it does nothing to
    // guarantee any of the four callbacks above ever fire at all if the
    // initial network request itself stalls. Without this, a flaky
    // connection leaves the caller's loading overlay up forever.
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => PhoneCodeResult.failed('Request timed out. Please try again.'),
    );
  }

  /// Verifies [smsCode] against [verificationId] and signs the user in.
  /// Throws [FirebaseAuthException] (e.g. `invalid-verification-code`,
  /// `session-expired`) on a wrong or expired code, or [TimeoutException]
  /// on a stalled connection — callers must handle both rather than
  /// leaving their loading overlay up forever on an unbounded await.
  Future<UserCredential> confirmCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth
        .signInWithCredential(credential)
        .timeout(const Duration(seconds: 15));
  }

  String _messageFor(Object e) =>
      e is FirebaseAuthException ? (e.message ?? e.code) : e.toString();
}
