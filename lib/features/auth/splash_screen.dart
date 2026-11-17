import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/services/user_service.dart';

import 'auth_fields.dart';
import 'auth_flow.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      var route = '/welcome';
      globalCitizenUser = null;
      if (user != null) {
        if (user.emailVerified) {
          await prepareVerifiedCitizen(user);
          route = '/dashboard';
        } else {
          route = '/verification';
        }
      }
      if (!mounted) return;
      AppSession.instance.leavePreview();
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signOut();
      globalCitizenUser = null;
      AppSession.instance.leavePreview();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: BrandMark(
                      compact: MediaQuery.textScalerOf(context).scale(1) > 1.2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_error == null) ...[
                    if (!reducedMotion)
                      const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        'Opening your community…',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    AuthMessage(message: _error!),
                    AsyncButton(
                      label: 'Try again',
                      icon: Icons.refresh_outlined,
                      isLoading: _busy,
                      onPressed: _busy ? null : _restoreSession,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      style: authTextButtonStyle(),
                      onPressed: _busy ? null : _signOut,
                      child: const Text('Sign out and return to welcome'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
