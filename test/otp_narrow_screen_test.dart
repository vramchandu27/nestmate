// The 6-box OTP row used fixed 42px-wide boxes with spaceBetween, which
// overflows on the narrowest real Android phones (~320dp wide). Confirms
// the Expanded-based layout no longer throws a RenderFlex overflow there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/config/localization/app_localizations.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/onboarding/otp_screen.dart';

void main() {
  testWidgets('OTP screen does not overflow on a 320dp-wide phone', (
    WidgetTester tester,
  ) async {
    AppLocalizations.setLanguage(AppLanguage.english);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => SocietyProvider.mock()),
        ],
        child: const MaterialApp(home: OtpScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(6));

    // Drain the screen's recursive 1-second resend-countdown timer so the
    // test doesn't end with a pending Timer (unrelated to the layout fix
    // this test targets, but flutter_test asserts none are left dangling).
    await tester.pump(const Duration(seconds: 31));
  });
}
