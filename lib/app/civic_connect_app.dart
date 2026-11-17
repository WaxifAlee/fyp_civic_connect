import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/civic_widgets.dart';
import '../features/account/change_password_screen.dart';
import '../features/account/notifications_screen.dart';
import '../features/account/profile.dart';
import '../features/auth/forgot_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/recovery_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/verification_waiting_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/authority/presentation/authority_entry.dart';
import '../features/reports/presentation/report_feed_screen.dart';
import '../features/reports/domain/report_filters.dart';
import '../features/reports/presentation/report_issue_screen.dart';
import '../services/supabase_client.dart';
import '../services/user_service.dart';
import 'app_session.dart';

class CivicConnectApp extends StatefulWidget {
  const CivicConnectApp({super.key, this.initialRoute});
  final String? initialRoute;

  @override
  State<CivicConnectApp> createState() => _CivicConnectAppState();
}

class _CivicConnectAppState extends State<CivicConnectApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    SupabaseService.navigation.addListener(_onAuthNavigation);
    _onAuthNavigation();
  }

  @override
  void dispose() {
    SupabaseService.navigation.removeListener(_onAuthNavigation);
    super.dispose();
  }

  void _onAuthNavigation() {
    final event = SupabaseService.navigation.value;
    if (event == null) return;
    SupabaseService.navigation.value = null;
    if (AppSession.instance.isPreview && event == AuthNavigation.signedOut) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      globalCitizenUser = null;
      AppSession.instance.leavePreview();
      final route = switch (event) {
        AuthNavigation.recovery => '/recover_password',
        AuthNavigation.confirmed =>
          SupabaseService.recoveryActive ? '/recover_password' : '/',
        AuthNavigation.signedOut || AuthNavigation.failed => '/login',
      };
      _navigator.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
      if (event == AuthNavigation.failed) {
        final context = _navigator.currentContext;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
              content: Text(
                  'This sign-in link could not be opened. Request a new link and try again.')));
        }
      }
    });
    // Auth callbacks can arrive while the app is idle with no frame scheduled.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: AppSession.instance,
      builder: (context, _) => MaterialApp(
            navigatorKey: _navigator,
            debugShowCheckedModeBanner: false,
            title: 'CivicConnect · Your community, connected',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: AppSession.instance.themeMode,
            initialRoute: widget.initialRoute ??
                (Uri.base.fragment == '/authority' ? '/authority' : '/'),
            routes: _routes,
            // An explicit entry point should not create a hidden bootstrap route.
            // Returning to '/' still initializes real services after leaving a demo.
            onGenerateInitialRoutes: widget.initialRoute == null &&
                    Uri.base.fragment != '/authority'
                ? null
                : (name) => [
                      MaterialPageRoute<void>(
                        settings: RouteSettings(name: name),
                        builder: _routes[name] ?? (_) => const WelcomeScreen(),
                      ),
                    ],
            onUnknownRoute: (_) =>
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          ));

  Map<String, WidgetBuilder> get _routes => {
        '/': (_) => const _AppBootstrap(),
        '/welcome': (_) => const WelcomeScreen(),
        '/home': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/signUp': (_) => const SignupScreen(),
        '/reset_password': (_) => const ForgotScreen(),
        '/recover_password': (_) => const RecoveryScreen(),
        '/verification': (_) => const VerificationWaitingScreen(),
        '/dashboard': (_) => _authenticated(const DashboardPage()),
        '/authority': (_) => const AuthorityEntry(),
        '/explore': (_) => _authenticated(const ExploreIssuesScreen()),
        '/my_reports': (context) {
          final status = ModalRoute.of(context)?.settings.arguments;
          return _authenticated(MyReportsScreen(
              initialStatus: status is ReportStatus ? status : null));
        },
        '/report_issue': (_) => _authenticated(const ReportIssueScreen()),
        '/profile': (_) => _authenticated(const Profile()),
        '/notifications': (_) => _authenticated(const NotificationsScreen()),
        '/change_password': (_) => _authenticated(const ChangePasswordScreen()),
      };

  Widget _authenticated(Widget child) {
    if (AppSession.instance.isPreview) return child;
    if (SupabaseService.recoveryActive) return const RecoveryScreen();
    if (!SupabaseService.isConfigured ||
        SupabaseService.client.auth.currentUser == null) {
      return const LoginScreen();
    }
    if (SupabaseService.client.auth.currentUser!.emailConfirmedAt == null) {
      return const VerificationWaitingScreen();
    }
    return child;
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();
  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<void> _initialization;
  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await AppSession.instance.restorePreferences();
    if (AppSession.instance.isPreview) return;
    await SupabaseService.initialize().timeout(const Duration(seconds: 20));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return SupabaseService.recoveryActive &&
                  !AppSession.instance.isPreview
              ? const RecoveryScreen()
              : AppSession.instance.isPreview
                  ? const DashboardPage()
                  : const SplashScreen();
        }
        return Scaffold(
            body: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const BrandMark(),
                                  const SizedBox(height: 40),
                                  if (snapshot.hasError) ...[
                                    const EmptyState(
                                        icon: Icons.cloud_off_outlined,
                                        title: 'We couldn’t get connected',
                                        message:
                                            'Check your connection and try again. You can also explore a demo of CivicConnect.'),
                                    AsyncButton(
                                        label: 'Try again',
                                        icon: Icons.refresh,
                                        onPressed: () => setState(() =>
                                            _initialization = _initialize())),
                                    const SizedBox(height: 12),
                                    TextButton(
                                        onPressed: () {
                                          AppSession.instance.enterPreview();
                                          Navigator.pushNamedAndRemoveUntil(
                                              context,
                                              '/dashboard',
                                              (_) => false);
                                        },
                                        child: const Text('Explore the demo'))
                                  ] else ...[
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 24),
                                    const Text('Opening your community…')
                                  ]
                                ]))))));
      });
}
