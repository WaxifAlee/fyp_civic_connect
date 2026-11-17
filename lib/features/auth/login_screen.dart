import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';

import 'auth_fields.dart';
import 'auth_flow.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService = const AuthService()});
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential =
          await widget.authService.signIn(_email.text.trim(), _password.text);
      if (!mounted) return;
      final user = credential.user;
      if (user == null) throw StateError('Missing authenticated user');
      AppSession.instance.leavePreview();
      if (user.emailVerified) await prepareVerifiedCitizen(user);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.pushNamedAndRemoveUntil(
        context,
        user.emailVerified ? '/dashboard' : '/verification',
        (route) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      backEnabled: !_busy,
      title: 'Welcome back',
      description: 'Sign in to report an issue or pick up where you left off.',
      children: [
        if (_error != null) AuthMessage(message: _error!),
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
