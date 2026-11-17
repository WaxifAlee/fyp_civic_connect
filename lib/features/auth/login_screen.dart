import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/core/widgets/form_validation.dart';

import 'auth_fields.dart';
import 'auth_flow.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key,
      this.authService = const AuthService(),
      this.destination = '/dashboard'});
  final AuthService authService;
  final String destination;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _needsVerification = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !validateAndReveal(_formKey.currentState)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _needsVerification = false;
    });
    final wasPreview = AppSession.instance.isPreview;
    try {
      final credential =
          await widget.authService.signIn(_email.text.trim(), _password.text);
      if (!mounted || AppSession.instance.isPreview != wasPreview) {
        return;
      }
      final user = credential.user;
      if (user == null || widget.authService.currentUser?.id != user.id) {
        throw StateError('Missing authenticated user');
      }
      AppSession.instance.leavePreview();
      if (user.emailConfirmedAt != null) await prepareVerifiedCitizen(user);
      if (!mounted ||
          AppSession.instance.isPreview ||
          widget.authService.currentUser?.id != user.id) {
        return;
      }
      TextInput.finishAutofillContext();
      Navigator.pushNamedAndRemoveUntil(
        context,
        user.emailConfirmedAt != null ? widget.destination : '/verification',
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyAuthError(error);
          _needsVerification =
              error is AuthException && error.code == 'email_not_confirmed';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      backEnabled: !_busy,
      title: widget.destination == '/authority'
          ? 'Service-team sign in'
          : 'Welcome back',
      description: widget.destination == '/authority'
          ? 'Use your assigned staff account to review reports and publish updates.'
          : 'Sign in to report an issue or pick up where you left off.',
      children: [
        if (_error != null) AuthMessage(message: _error!),
        if (_needsVerification)
          TextButton(
            style: authTextButtonStyle(),
            onPressed: _busy
                ? null
                : () => Navigator.pushNamed(context, '/verification'),
            child: const Text('Verify email / resend link'),
          ),
        AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  controller: _email,
                  label: 'Email address',
                  icon: Icons.alternate_email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  validator: validateAuthEmail,
                  enabled: !_busy,
                ),
                AuthField(
                  controller: _password,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  password: true,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password.'
                      : null,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: authTextButtonStyle(),
                    onPressed: _busy
                        ? null
                        : () => Navigator.pushNamed(context, '/reset_password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 16),
                AsyncButton(
                  label: 'Sign in',
                  icon: Icons.arrow_forward_outlined,
                  onPressed: _busy ? null : _signIn,
                  isLoading: _busy,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('New to CivicConnect?'),
            TextButton(
              style: authTextButtonStyle(),
              onPressed: _busy
                  ? null
                  : () => Navigator.pushReplacementNamed(context, '/signUp'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}
