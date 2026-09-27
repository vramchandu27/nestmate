/// Formats a bare Indian phone number as E.164 for Firebase Auth, e.g.
/// "98765 43210" -> "+919876543210".
///
/// Always strips to digits and keeps only the last 10 (a real Indian
/// mobile number's length) before prepending +91 — deliberately NOT just
/// passing through anything already starting with "+". Android's autofill
/// can bypass this field's digit-only TextInputFormatters and inject a
/// full "+"-prefixed number straight into the controller (e.g. a "+1"
/// US-formatted suggestion from the OS/Google account), which used to
/// sail through here unchanged and get sent to Firebase as a real E.164
/// number — silently sending the OTP to the wrong country and failing
/// against this India-only project's SMS region allowlist. Since this app
/// only ever serves Indian numbers, forcing +91 + the last 10 digits is
/// always correct and immune to that class of bad input.
String toE164Phone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  final last10 = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  return '+91$last10';
}

/// Deterministic placeholder email for Firebase Auth's Email/Password
/// provider — [phone]'s real identity is the phone number itself, verified
/// once via OTP at signup. This email only exists so that same Firebase
/// user can also sign in with the password they set at signup (linked via
/// [EmailAuthProvider]), without needing a fresh SMS on every login.
String passwordAuthEmailFor(String phone) {
  final digits = toE164Phone(phone).replaceAll('+', '');
  return '$digits@nestmate-password.app';
}
