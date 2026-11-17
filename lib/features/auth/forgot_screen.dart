import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/core/widgets/form_validation.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';

import 'auth_fields.dart';
import 'auth_layout.dart';
import 'auth_flow.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key, this.authService = const AuthService()});
  final AuthService authService;

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (_busy || !validateAndReveal(_formKey.currentState)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Keep account existence private for every successful reset request.
      await widget.authService.sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      backEnabled: !_busy,
      title: _sent ? 'Check your inbox' : 'Forgot your password?',
      description: _sent
          ? 'If an account matches that address, you’ll receive a password reset link. Check your spam folder too.'
          : 'Enter your email address and we’ll help you get back to your account.',
      backRoute: '/login',
      storyTitle: 'A fresh start.\nThe same community.',
      children: [
        if (_error != null) AuthMessage(message: _error!),
        if (_sent) ...[
          const AuthMessage(
            message: 'Reset request received. If no email arrives, check the '
                'address and try again in a few minutes.',
            isError: false,
          ),
          AsyncButton(
            label: 'Back to sign in',
            icon: Icons.arrow_forward_outlined,
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: authTextButtonStyle(),
            onPressed: () => setState(() => _sent = false),
            child: const Text('Use another email address'),
          ),
        ] else
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthField(
                    controller: _email,
                    label: 'Email address',
                    icon: Icons.alternate_email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: validateAuthEmail,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendReset(),
                  ),
                  const SizedBox(height: 8),
                  AsyncButton(
                    label: 'Send reset link',
                    icon: Icons.mail_outline,
                    onPressed: _busy ? null : _sendReset,
                    isLoading: _busy,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    style: authTextButtonStyle(),
                    onPressed: _busy
                        ? null
                        : () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
