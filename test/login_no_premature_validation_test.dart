// Reproduces the reported bug: fill only the phone field, never tap
// Login, and the password field must NOT show its error. Also checks
// that switching the Resident/Admin tab doesn't surface it either.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/config/localization/app_localizations.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/onboarding/login_screen.dart';

void main() {
  testWidgets(
    'typing only the phone number, without tapping Login, must not show '
    'the password error — even after switching Resident/Admin tabs',
    (WidgetTester tester) async {
      AppLocalizations.setLanguage(AppLanguage.english);
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

      await tester.enterText(find.byType(TextFormField).first, '9876543210');
      await tester.pump();

      expect(
        find.text('Please enter your password'),
        findsNothing,
        reason: 'No submit attempt happened yet — no error should show.',
      );

      // Switch to the Admin tab.
      await tester.tap(find.text('Admin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text('Please enter your password'),
        findsNothing,
        reason: 'Switching tabs must not surface a premature error either.',
      );
    },
  );
}
