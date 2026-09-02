/// Formats a bare Indian phone number as E.164 for Firebase Auth, e.g.
/// "98765 43210" -> "+919876543210". Input already starting with "+" is
/// passed through unchanged.
String toE164Phone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('+')) return trimmed;
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return '+91$digits';
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
