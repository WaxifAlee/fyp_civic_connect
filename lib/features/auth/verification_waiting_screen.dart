import 'dart:async';

import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/services/user_service.dart';

import 'auth_fields.dart';
import 'auth_flow.dart';
import 'auth_layout.dart';

class VerificationWaitingScreen extends StatefulWidget {
  const VerificationWaitingScreen(
      {super.key, this.authService = const AuthService()});
  final AuthService authService;

  @override
  State<VerificationWaitingScreen> createState() =>
      _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends State<VerificationWaitingScreen>
    with WidgetsBindingObserver {
  Timer? _cooldownTimer;
  DateTime? _resendAt;
  bool _checking = false;
  bool _sending = false;
  bool _signingOut = false;
  String? _error;
  String? _notice;

  bool get _busy => _checking || _sending || _signingOut;
  int get _remaining {
    final until = _resendAt;
    if (until == null) return 0;
    final seconds =
        (until.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    return seconds > 0 ? seconds : 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _checkVerification();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _resendAt = DateTime.now().add(const Duration(seconds: 120));
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (_remaining == 0) timer.cancel();
    });
  }

  Future<void> _checkVerification() async {
    if (_busy) {
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    final wasPreview = AppSession.instance.isPreview;
    try {
      final user = await widget.authService.refreshUser();
      if (!mounted || AppSession.instance.isPreview != wasPreview) {
        return;
      }
      if (user == null) {
        setState(() =>
            _notice = 'If you opened a confirmation link in another browser, '
                'sign in here to continue. You can also check your inbox or resend below.');
        return;
      }
      if (user.emailConfirmedAt == null) {
        if (mounted) {
          setState(
            () => _notice = 'Your email hasn’t been verified yet. Open '
                'the link in your email, then check again.',
          );
        }
        return;
      }
      if (widget.authService.currentUser?.id != user.id) {
        return;
      }
      AppSession.instance.leavePreview();
      await prepareVerifiedCitizen(user);
      if (!mounted ||
          AppSession.instance.isPreview ||
          widget.authService.currentUser?.id != user.id) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _remaining > 0) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.authService.resendVerification();
      if (!mounted) {
        return;
      }
      setState(() {
        _notice =
            'If confirmation is pending for that address, check your inbox and spam folder for a link.';
        _startCooldown();
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) {
      return;
    }
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      final wasPreview = AppSession.instance.isPreview;
      await widget.authService.signOut();
      if (!mounted ||
          AppSession.instance.isPreview != wasPreview ||
          widget.authService.currentUser != null) {
        return;
      }
      globalCitizenUser = null;
      AppSession.instance.leavePreview();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = widget.authService.pendingVerificationEmail ??
        widget.authService.currentUser?.email;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _signOut();
      },
      child: AuthLayout(
        title: 'Check your email',
        description:
            'Check your inbox for any confirmation link, or sign in if you already have an account.',
        onBack: _signOut,
        backEnabled: !_busy,
        storyTitle: 'Your voice belongs\nhere.',
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.mark_email_unread_outlined,
                size: 40,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (email != null) ...[
            Text('Your email address', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(email, style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
          ],
          const Text(
            'Open the verification link in your email, then return here. '
            'If you haven’t received a link, request one below.',
          ),
          const SizedBox(height: 24),
          if (_error != null) AuthMessage(message: _error!),
          if (_notice != null) AuthMessage(message: _notice!, isError: false),
          AsyncButton(
            label: 'I’ve verified my email',
            icon: Icons.verified_outlined,
            onPressed: _busy ? null : _checkVerification,
            isLoading: _checking,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _busy || _remaining > 0 ? null : _resend,
            icon: const Icon(Icons.send_outlined),
            label: Text(
              _sending
                  ? 'Sending…'
                  : _remaining > 0
                      ? 'Resend available in ${_remaining}s'
                      : 'Resend verification email',
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: authTextButtonStyle(),
            onPressed: _busy ? null : _signOut,
            child: const Text('Sign in after confirming your email'),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: authTextButtonStyle(),
            onPressed: _busy ? null : _signOut,
            child: Text(
              _signingOut ? 'Signing out…' : 'Sign out / use another account',
            ),
          ),
        ],
      ),
    );
  }
}
