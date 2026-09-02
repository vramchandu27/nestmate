// Verifies the exact scenario reported: fill only the phone field, leave
// password empty, tap Login. Expected: an inline error appears under the
// empty password field, and login is blocked (no navigation happens).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/config/localization/app_localizations.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/onboarding/login_screen.dart';
import 'package:nestmate/screens/onboarding/otp_screen.dart';

void main() {
  testWidgets(
    'filling only the phone field and tapping Login shows a password '
    'error and does not navigate away',
    (WidgetTester tester) async {
      AppLocalizations.setLanguage(AppLanguage.english);

      // The default 800x600 test surface is too short for this form —
      // the Login button sits below the fold, so a tap on it would
      // silently miss (hit-testing the root view instead) and produce a
      // false-positive "pass". Use a taller surface so the button is
      // actually reachable, matching a real phone screen.
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
            ChangeNotifierProvider(create: (_) => SocietyProvider.mock()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      // No error should show before any interaction at all.
      expect(find.text('Please enter your password'), findsNothing);

      // Fill only the phone field.
      await tester.enterText(find.byType(TextFormField).first, '9876543210');
      await tester.pump();

      // Password field is left empty. Tap Login — confirm the tap
      // actually lands on the button, not the false-positive miss from
      // before.
      final loginButton = find.text('Login');
      expect(
        tester.getRect(loginButton).bottom,
        lessThanOrEqualTo(900),
        reason: 'Login button must be within the test viewport to tap it',
      );
      await tester.tap(loginButton, warnIfMissed: true);
      await tester.pump(); // let setState/validate run
      await tester.pump(const Duration(milliseconds: 50));

      // The password error should be visible below the field.
      expect(find.text('Please enter your password'), findsOneWidget);

      // Must still be on the login screen — nothing navigated.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
    },
  );
}
