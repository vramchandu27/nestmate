// Verifies the dashboard notification bell no longer always opens Issues
// regardless of what its badge is counting — it now opens a unified
// Notifications screen that lists both pending payment confirmations and
// open issues, each routing to the screen that actually explains it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/config/localization/app_localizations.dart';
import 'package:nestmate/models/bill.dart';
import 'package:nestmate/models/issue_report.dart';
import 'package:nestmate/models/role.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/admin/admin_dashboard_screen.dart';
import 'package:nestmate/screens/admin/confirm_payments_screen.dart';
import 'package:nestmate/screens/admin/issues_screen.dart';
import 'package:nestmate/screens/admin/notifications_screen.dart';

void main() {
  testWidgets(
    'the bell badge count matches the notifications list, and each item '
    'routes to the right screen',
    (WidgetTester tester) async {
      AppLocalizations.setLanguage(AppLanguage.english);

      final appProvider = AppProvider()..setUserRole(UserRole.communityAdmin);
      final societyProvider = SocietyProvider.mock();

      // One pending payment confirmation on top of whatever the seed data
      // already has — a mixed badge count (payments + issues) is exactly
      // the case that used to route to the wrong place (always Issues,
      // even when the badge was partly counting payments).
      societyProvider.generateBills();
      societyProvider.submitPaymentScreenshot('402');
      societyProvider.addIssue(
        title: 'Leaking tap',
        type: 'Plumbing',
        location: 'Flat 403',
        flatNumber: '403',
      );
      final expectedBadgeCount =
          societyProvider.currentMonth.bills
              .where((b) => b.status == BillStatus.screenshotUploaded)
              .length +
          societyProvider.issues
              .where((i) => i.status != IssueStatus.resolved)
              .length;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: appProvider),
            ChangeNotifierProvider<SocietyProvider>.value(
              value: societyProvider,
            ),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );

      // Badge shows the combined count.
      expect(find.text('$expectedBadgeCount'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      // SectionHeader renders its label uppercased.
      expect(find.text('AWAITING CONFIRMATION'), findsOneWidget);
      final flat402ResidentName = societyProvider
          .flatByNumber('402')!
          .residentName;
      final paymentRow = find.text('Flat 402 · $flat402ResidentName');
      expect(paymentRow, findsOneWidget);

      // Tapping the payment notification opens Confirm Payments, not
      // Issues (the bug this replaces: the bell used to always open
      // Issues, regardless of what its badge was actually counting).
      await tester.tap(paymentRow);
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmPaymentsScreen), findsOneWidget);
      expect(find.byType(IssuesScreen), findsNothing);
    },
  );
}
