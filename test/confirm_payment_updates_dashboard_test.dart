// Verifies that confirming a payment actually updates the admin
// dashboard's collection progress ring — not just the underlying data.
// Pumps the real AdminDashboardScreen widget and drives the state change
// through SocietyProvider.confirmPayment, the exact same call the
// Confirm Payments screen's "Confirm" button makes, so a rebuild bug in
// the dashboard would be caught here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nestmate/config/localization/app_localizations.dart';
import 'package:nestmate/models/role.dart';
import 'package:nestmate/providers/app_provider.dart';
import 'package:nestmate/providers/society_provider.dart';
import 'package:nestmate/screens/admin/admin_dashboard_screen.dart';
import 'package:nestmate/widgets/collection_ring.dart';

void main() {
  testWidgets('confirming a payment updates the dashboard collection ring', (
    WidgetTester tester,
  ) async {
    AppLocalizations.setLanguage(AppLanguage.english);

    final appProvider = AppProvider()..setUserRole(UserRole.communityAdmin);
    final societyProvider = SocietyProvider.mock();

    // Freeze this month's bills, then simulate one resident (flat 402,
    // the seeded demo flat) submitting a payment screenshot — exactly
    // the state that makes a bill eligible for confirmation.
    societyProvider.generateBills();
    societyProvider.submitPaymentScreenshot('402');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ChangeNotifierProvider<SocietyProvider>.value(value: societyProvider),
        ],
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );

    final percentBefore = societyProvider.collectionPercent;
    CollectionRing ring = tester.widget(find.byType(CollectionRing));
    expect(
      ring.percent,
      closeTo(percentBefore, 0.0001),
      reason: 'ring should start showing the pre-confirmation percentage',
    );

    // This is the exact call ConfirmPaymentsScreen's "Confirm" button
    // makes (see _PaymentCard.onConfirm in confirm_payments_screen.dart)
    // — while AdminDashboardScreen stays mounted underneath, same as it
    // would in the real app (pushed on top via Navigator.push).
    societyProvider.confirmPayment('402');
    await tester.pump();

    final percentAfter = societyProvider.collectionPercent;
    expect(
      percentAfter,
      greaterThan(percentBefore),
      reason: 'confirming a payment should raise the collected percentage',
    );

    ring = tester.widget(find.byType(CollectionRing));
    expect(
      ring.percent,
      closeTo(percentAfter, 0.0001),
      reason:
          "the dashboard's CollectionRing must rebuild with the updated "
          'percentage as soon as SocietyProvider notifies listeners — '
          'it takes percent as a plain constructor prop with no '
          'internal caching, so a stale value here would mean the '
          'widget tree above it failed to rebuild.',
    );
  });
}
