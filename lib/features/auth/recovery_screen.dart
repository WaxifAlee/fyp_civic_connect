import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';
import 'package:fyp_civic_connect/services/user_service.dart';

import 'auth_fields.dart';
import 'auth_flow.dart';
import 'auth_layout.dart';

/// Opened by the app's passwordRecovery auth event at /recover_password.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, this.authService = const AuthService()});
  final AuthService authService;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _updated = false;
  String? _error;

  bool get _hasSession =>
      !AppSession.instance.isPreview &&
      widget.authService.currentSession != null;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_busy || !_hasSession || !_form.currentState!.validate()) {
      return;
    }
    final userId = widget.authService.currentUser?.id;
    final accessToken = widget.authService.currentSession?.accessToken;
    if (userId == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.updatePassword(_password.text);
      if (!mounted ||
          !_hasSession ||
          widget.authService.currentUser?.id != userId ||
          widget.authService.currentSession?.accessToken != accessToken) {
        return;
      }
      _password.clear();
      _confirmation.clear();
      TextInput.finishAutofillContext();
      setState(() => _updated = true);
      await widget.authService.signOut();
      if (!mounted ||
          AppSession.instance.isPreview ||
          widget.authService.currentUser != null) {
        return;
      }
      globalCitizenUser = null;
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final wasPreview = AppSession.instance.isPreview;
    try {
      if (!wasPreview) await widget.authService.signOut();
      if (!mounted ||
          AppSession.instance.isPreview != wasPreview ||
          (!wasPreview && widget.authService.currentUser != null)) {
        return;
      }
      if (!wasPreview) globalCitizenUser = null;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: _updated ? 'Password updated' : 'Choose a new password',
      description: _updated
          ? 'Your password has been changed. Sign in with your new password.'
          : 'Use the recovery link from your email to secure your account.',
      onBack: _signIn,
      backEnabled: !_busy,
      children: [
        if (_error != null) AuthMessage(message: _error!),
        if (!_updated && !_hasSession) ...[
          const AuthMessage(
            message: 'This recovery session is unavailable or has expired. '
                'Request a fresh password reset link from sign in.',
          ),
        ] else if (!_updated)
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthField(
                    controller: _password,
                    label: 'New password',
                    icon: Icons.lock_outline,
                    password: true,
                    autofillHints: const [AutofillHints.newPassword],
                    helperText:
                        'Use 8–64 characters with uppercase and lowercase '
                        'letters, a number, and a symbol.',
                    validator: validateNewAuthPassword,
                    enabled: !_busy,
                  ),
                  AuthField(
                    controller: _confirmation,
                    label: 'Confirm new password',
                    icon: Icons.lock_outline,
                    password: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) => value == null || value.isEmpty
                        ? 'Confirm your password.'
                        : value != _password.text
                            ? 'Your passwords don’t match.'
                            : null,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _updatePassword(),
                  ),
                  AsyncButton(
                    label: 'Update password',
                    icon: Icons.lock_reset_outlined,
                    onPressed: _busy ? null : _updatePassword,
                    isLoading: _busy,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextButton(
          style: authTextButtonStyle(),
          onPressed: _busy ? null : _signIn,
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
