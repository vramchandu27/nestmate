import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/localization/app_localizations.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/personal_expense_provider.dart';
import 'providers/society_provider.dart';
import 'screens/onboarding/language_selection_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/otp_screen.dart';
import 'screens/onboarding/signup_screen.dart';
import 'screens/onboarding/admin_signup_screen.dart';
import 'screens/resident/resident_shell_screen.dart';
import 'screens/resident/bill_breakdown_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/block_setup_screen.dart';
import 'screens/admin/add_people_screen.dart';
import 'screens/admin/join_association_screen.dart';
import 'screens/admin/expenses_screen.dart';
import 'screens/admin/add_expense_screen.dart';
import 'screens/admin/add_advance_screen.dart';
import 'screens/admin/water_calculator_screen.dart';
import 'screens/admin/generate_bills_screen.dart';
import 'screens/admin/confirm_payments_screen.dart';
import 'screens/admin/flats_management_screen.dart';
import 'screens/admin/issues_screen.dart';
import 'screens/admin/add_notice_screen.dart';
import 'screens/admin/transfer_admin_screen.dart';
import 'screens/committee/committee_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize localization with default language
  AppLocalizations.setLanguage(AppLanguage.english);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => SocietyProvider()),
        ChangeNotifierProvider(create: (_) => PersonalExpenseProvider()),
      ],
      child: const NestMateApp(),
    ),
  );
}

class NestMateApp extends StatelessWidget {
  const NestMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        return MaterialApp(
          title: 'NestMate',
          theme: AppTheme.lightTheme(language: appProvider.language),
          locale: appProvider.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          home: const LanguageSelectionScreen(),
          // Navigation routes
          routes: {
            '/language': (context) => const LanguageSelectionScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/otp': (context) => const OtpScreen(),
            '/signup': (context) => const SignupScreen(),
            '/admin-signup': (context) => const AdminSignupScreen(),
            '/resident-shell': (context) => const ResidentShellScreen(),
            '/bill-breakdown': (context) => const BillBreakdownScreen(),
            '/admin-dashboard': (context) => const AdminDashboardScreen(),
            '/admin-setup': (context) => const BlockSetupScreen(),
            '/admin-add-people': (context) => const AddPeopleScreen(),
            '/admin-join-association': (context) =>
                const JoinAssociationScreen(),
            '/admin-expenses': (context) => const ExpensesScreen(),
            '/admin-add-expense': (context) => const AddExpenseScreen(),
            '/admin-add-advance': (context) => const AddAdvanceScreen(),
            '/admin-water-calc': (context) => const WaterCalculatorScreen(),
            '/admin-generate-bills': (context) => const GenerateBillsScreen(),
            '/admin-confirm-payments': (context) =>
                const ConfirmPaymentsScreen(),
            '/admin-flats': (context) => const FlatsManagementScreen(),
            '/admin-issues': (context) => const IssuesScreen(),
            '/admin-add-notice': (context) => const AddNoticeScreen(),
            '/admin-transfer-admin': (context) => const TransferAdminScreen(),
            '/committee-dashboard': (context) =>
                const CommitteeDashboardScreen(),
          },
        );
      },
    );
  }
}
