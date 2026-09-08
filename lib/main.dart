import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/localization/app_localizations.dart';
import 'config/routing.dart';
import 'firebase_options.dart';
import 'models/role.dart';
import 'providers/app_provider.dart';
import 'providers/personal_expense_provider.dart';
import 'providers/society_provider.dart';
import 'services/push_notification_service.dart';
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

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PushNotificationService().init(navigatorKey);

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

/// Checked once at app launch, before anything else — Firebase already
/// keeps a signed-in session alive across restarts on its own, but nothing
/// was ever checking for it, so the app always forced Welcome → Login
/// again regardless. This resumes straight to the right dashboard when
/// [tryResumeSession] finds a still-valid session (signed in AND logged in
/// within the last week), falling back to the normal Language Selection
/// flow otherwise.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  Future<void> _resume() async {
    final route = await tryResumeSession(context);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route ?? '/language');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// How long the app can sit backgrounded before reopening it resets back to
/// the dashboard instead of resuming whatever screen was left open —
/// Android/iOS keep the app process (and its whole widget/navigator state)
/// alive across a mere backgrounding, so without this, reopening after a
/// long gap just shows the exact same screen from before, stale data and
/// all, with no re-check of anything.
const _backgroundResetThreshold = Duration(minutes: 15);

class NestMateApp extends StatefulWidget {
  const NestMateApp({super.key});

  @override
  State<NestMateApp> createState() => _NestMateAppState();
}

class _NestMateAppState extends State<NestMateApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;
    if (DateTime.now().difference(pausedAt) < _backgroundResetThreshold) return;
    _resetToDashboardIfSignedIn();
  }

  /// Only resets when there's an actual signed-in session with a role
  /// already resolved — someone sitting on Welcome/Login/a signup form
  /// (never authenticated yet) must never get force-navigated away from
  /// whatever they were doing there.
  void _resetToDashboardIfSignedIn() {
    if (FirebaseAuth.instance.currentUser == null) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    if (ctx.read<AppProvider>().userRole == UserRole.none) return;
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      resolvePostAuthRoute(ctx),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
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
          home: const _AuthGate(),
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
