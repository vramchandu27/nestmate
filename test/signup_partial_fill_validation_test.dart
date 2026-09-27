// Same scenario as login_partial_fill_validation_test.dart but for the
// resident signup form, which has more fields: fill only the flat
// number, leave everything else empty, tap Create Account. Expected:
// inline errors on every other empty field, and no navigation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/config/localization/app_localizations.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/onboarding/signup_screen.dart';

void main() {
  testWidgets(
    'filling only the flat number field and tapping Create Account shows '
    'errors on every other field and does not navigate away',
    (WidgetTester tester) async {
      AppLocalizations.setLanguage(AppLanguage.english);

      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
            ChangeNotifierProvider(create: (_) => SocietyProvider.mock()),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      // Fill only the flat number field. It's the second TextFormField now
      // — the join code that identifies which society the resident is
      // joining comes first.
      await tester.enterText(find.byType(TextFormField).at(1), '101');
      await tester.pump();

      final createAccountButton = find.widgetWithText(
        ElevatedButton,
        'Create Account',
      );
      expect(
        tester.getRect(createAccountButton).bottom,
        lessThanOrEqualTo(1400),
        reason: 'button must be within the viewport to tap it',
      );
      await tester.tap(createAccountButton, warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Name, phone, password, and terms should all show their errors —
      // this is the multi-field version of the reported scenario.
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
      expect(
        find.text('Please agree to terms and conditions'),
        findsOneWidget,
      );

      // Still on the signup screen — nothing navigated, no account made.
      expect(find.byType(SignupScreen), findsOneWidget);
    },
  );

  testWidgets(
    'leaving confirm-password empty while password is filled shows a '
    'mismatch error on confirm-password specifically',
    (WidgetTester tester) async {
      AppLocalizations.setLanguage(AppLanguage.english);

      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
            ChangeNotifierProvider(create: (_) => SocietyProvider.mock()),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      final fields = find.byType(TextFormField);
      // Order in the form: joinCode, flatNumber, name, phone, password,
      // confirm.
      await tester.enterText(fields.at(0), 'SAV-2K4M');
      await tester.enterText(fields.at(1), '101');
      await tester.enterText(fields.at(2), 'Test Resident');
      await tester.enterText(fields.at(3), '9876543210');
      await tester.enterText(fields.at(4), 'password123');
      // fields.at(5) — confirm password — deliberately left empty.
      await tester.pump();

      final createAccountButton = find.widgetWithText(
        ElevatedButton,
        'Create Account',
      );
      await tester.tap(createAccountButton, warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(find.byType(SignupScreen), findsOneWidget);
    },
  );
}
