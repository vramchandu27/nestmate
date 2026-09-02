// Basic smoke test: the app should launch straight into language
// selection, wrapped in the same providers main() sets up.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/main.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/onboarding/language_selection_screen.dart';

void main() {
  testWidgets('App launches to the language selection screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => SocietyProvider.mock()),
        ],
        child: const NestMateApp(),
      ),
    );

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.text('NestMate'), findsOneWidget);
  });
}
