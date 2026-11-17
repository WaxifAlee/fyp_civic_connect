import 'package:flutter/material.dart';
import '../../../app/app_session.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../../../services/supabase_client.dart';
import '../../auth/login_screen.dart';
import '../../auth/recovery_screen.dart';
import '../../auth/verification_waiting_screen.dart';
import 'authority_workspace_screen.dart';

/// A standalone web entry initializes services before checking staff access.
class AuthorityEntry extends StatefulWidget {
  const AuthorityEntry({super.key});
  @override
  State<AuthorityEntry> createState() => _AuthorityEntryState();
}

class _AuthorityEntryState extends State<AuthorityEntry> {
  late Future<void> _ready;
  @override
  void initState() {
    super.initState();
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    await AppSession.instance.restorePreferences();
    if (!AppSession.instance.isPreview) {
      await SupabaseService.initialize().timeout(const Duration(seconds: 20));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: SafeArea(child: Center(child: LoadingState())));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: SafeArea(
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: EmptyState(
                                  icon: Icons.cloud_off_outlined,
                                  title: 'The workspace could not be opened',
                                  message:
                                      'Check your connection and service configuration, then try again.',
                                  actionLabel: 'Try again',
                                  onAction: () => setState(
                                      () => _ready = _initialize())))))));
        }
        if (AppSession.instance.isPreview) {
          return const AuthorityWorkspaceScreen();
        }
        if (SupabaseService.recoveryActive) return const RecoveryScreen();
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) return const LoginScreen(destination: '/authority');
        if (user.emailConfirmedAt == null) {
          return const VerificationWaitingScreen();
        }
        return const AuthorityWorkspaceScreen();
      });
}
