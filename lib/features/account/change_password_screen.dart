import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/core/widgets/form_validation.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';
import 'package:fyp_civic_connect/utils/validators.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmationVisible = false;
  bool _saving = false;
  bool _updated = false;
  String? _error;
  String? _currentError;
  String? _newError;

  bool get _isPreview => AppSession.instance.isPreview;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  Future<void> _changePassword() async {
    if (_saving || _isPreview) return;
    setState(() {
      _error = null;
      _currentError = null;
      _newError = null;
    });
    if (!validateAndReveal(_formKey.currentState)) return;
    FocusScope.of(context).unfocus();
    // Passwords are deliberately passed through without trimming or rewriting.
    final currentPassword = _currentPassword.text;
    final newPassword = _newPassword.text;
    setState(() => _saving = true);
    try {
      if (!SupabaseService.isConfigured) {
        throw StateError(
          'Account services are unavailable. Please try again '
          'later.',
        );
      }
      final auth = SupabaseService.client.auth;
      final user = auth.currentUser;
      if (user == null || user.email == null) {
        throw StateError(
          'Sign in with your email and password before changing '
          'your password.',
        );
      }
      await auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      if (!mounted || _isPreview || auth.currentUser?.id != user.id) return;
      await auth.updateUser(UserAttributes(password: newPassword));
      if (!mounted) return;
      TextInput.finishAutofillContext();
      _currentPassword.clear();
      _newPassword.clear();
      _confirmation.clear();
      setState(() => _updated = true);
      // Preserve the existing app's requirement to sign in after an update.
      await _signOutAfterUpdate();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        switch (error.code) {
          case 'invalid_credentials':
            _currentError = 'The current password is incorrect. Try again.';
          case 'weak_password':
          case 'same_password':
            _newError = 'Choose a stronger password using the guidance below.';
          case 'over_request_rate_limit':
            _error = 'Too many attempts. Wait a while before trying again.';
          case 'network_error':
            _error = 'Check your internet connection and try again.';
          case 'session_not_found':
          case 'refresh_token_not_found':
          case 'bad_jwt':
            _error = 'Your session has expired. Sign in again, then retry.';
          case 'user_banned':
            _error =
                'This account is disabled. Password changes are unavailable.';
          default:
            _error = 'We couldn’t update your password. Please try again.';
        }
      });
      _formKey.currentState?.validate();
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We couldn’t update your password. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOutAfterUpdate() async {
    try {
      if (_isPreview) return;
      await SupabaseService.client.auth.signOut();
      globalCitizenUser = null;
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password updated. Sign in with your new password.'),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your password was updated, but sign out did '
              'not finish. Try signing out again below.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Change password'),
          leading: IconButton(
            tooltip: 'Back to your account',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: _saving ? null : _back,
            icon: const Icon(Icons.arrow_back_outlined),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Entrance(
                  child: AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: ExcludeSemantics(
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 32,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Keep your account secure',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your current password to confirm it’s '
                          'you. After updating, sign in again with your new '
                          'password.',
                        ),
                        const SizedBox(height: 24),
                        if (_isPreview)
                          EmptyState(
                            icon: Icons.visibility_outlined,
                            title:
                                'Password changes are unavailable in preview',
                            message:
                                'This is a demo citizen account. Sign in to '
                                'your own account to change its password.',
                            actionLabel: 'Back to your account',
                            onAction: _back,
                          )
                        else if (_updated) ...[
                          const Text('Your password has been updated.'),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _errorMessage(context),
                          ],
                          const SizedBox(height: 24),
                          AsyncButton(
                            label: 'Sign out and continue',
                            icon: Icons.logout_outlined,
                            isLoading: _saving,
                            onPressed: _saving
                                ? null
                                : () async {
                                    setState(() => _saving = true);
                                    await _signOutAfterUpdate();
                                    if (mounted) {
                                      setState(() => _saving = false);
                                    }
                                  },
                          ),
                        ] else
                          _passwordForm(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordForm(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _passwordField(
              label: 'Current password',
              controller: _currentPassword,
              visible: _currentVisible,
              autofillHints: const [AutofillHints.password],
              onVisibility: () =>
                  setState(() => _currentVisible = !_currentVisible),
              onChanged: (_) {
                if (_currentError != null) {
                  setState(() => _currentError = null);
                }
              },
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your current password'
                  : _currentError,
            ),
            const SizedBox(height: 20),
            _passwordField(
              label: 'New password',
              controller: _newPassword,
              visible: _newVisible,
              autofillHints: const [AutofillHints.newPassword],
              onVisibility: () => setState(() => _newVisible = !_newVisible),
              onChanged: (_) {
                if (_newError != null) setState(() => _newError = null);
              },
              validator: (value) {
                final error = Validators.validatePassword(value);
                if (error != null) return error;
                if (value == _currentPassword.text) {
                  return 'Choose a password different from your current one';
                }
                return _newError;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Use 8–64 characters with uppercase and lowercase letters, '
              'a number, and one of these symbols: @ \$ ! % * ? &.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            _passwordField(
              label: 'Confirm new password',
              controller: _confirmation,
              visible: _confirmationVisible,
              autofillHints: const [AutofillHints.newPassword],
              last: true,
              onVisibility: () =>
                  setState(() => _confirmationVisible = !_confirmationVisible),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your new password';
                }
                if (value != _newPassword.text) return 'Passwords do not match';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              _errorMessage(context),
            ],
            const SizedBox(height: 24),
            AsyncButton(
              label: 'Update password',
              icon: Icons.lock_reset_outlined,
              isLoading: _saving,
              onPressed: _saving ? null : _changePassword,
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _saving
                  ? null
                  : () => Navigator.pushNamed(context, '/reset_password'),
              child: const Text('Forgot your current password?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onVisibility,
    required FormFieldValidator<String> validator,
    required List<String> autofillHints,
    ValueChanged<String>? onChanged,
    bool last = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: autofillHints,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        errorMaxLines: 4,
        suffixIcon: IconButton(
          tooltip: '${visible ? 'Hide' : 'Show'} ${label.toLowerCase()}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _saving ? null : onVisibility,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: last ? (_) => _changePassword() : null,
    );
  }

  Widget _errorMessage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _error!,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.onErrorContainer),
        ),
      ),
    );
  }
}
