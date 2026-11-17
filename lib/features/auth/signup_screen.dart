import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/services/auth_service.dart';

import 'auth_fields.dart';
import 'auth_flow.dart';
import 'auth_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.authService = const AuthService()});
  final AuthService authService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _accountForm = GlobalKey<FormState>();
  final _identityForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _cnic = TextEditingController();
  String? _gender;
  int _step = 0;
  bool _consent = false;
  bool _busy = false;
  String? _error;

  bool get _locked => _busy;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirmation,
      _address,
      _phone,
      _cnic,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _continue() {
    if (_busy || !_accountForm.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _register() async {
    if (_busy || !_identityForm.currentState!.validate()) {
      return;
    }
    if (!_consent) {
      setState(() =>
          _error = 'Confirm your consent to create your citizen account.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final wasPreview = AppSession.instance.isPreview;
    try {
      final response = await widget.authService.signUp(
        email: _email.text,
        password: _password.text,
        fullName: _name.text,
        phone: _phone.text,
        cnic: _cnic.text,
        location: _address.text,
        gender: _gender!,
      );
      if (!mounted || AppSession.instance.isPreview != wasPreview) {
        return;
      }
      // Empty identities can be Supabase's deliberately ambiguous duplicate
      // response. Never call it a newly created account or load its profile.
      if (response.user?.identities?.isEmpty != false ||
          response.session == null) {
        AppSession.instance.leavePreview();
        TextInput.finishAutofillContext();
        Navigator.pushNamedAndRemoveUntil(
            context, '/verification', (_) => false);
        return;
      }
      final user = response.user;
      if (user == null || widget.authService.currentUser?.id != user.id) {
        return;
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
        user.emailConfirmedAt != null ? '/dashboard' : '/verification',
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    if (_busy) {
      return;
    }
    if (_step == 1) {
      setState(() {
        _step = 0;
        _error = null;
      });
    } else {
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  void _showDataDetails() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your registration details'),
        content: const SingleChildScrollView(
          child: Text(
            'Registration saves your name, email, phone, CNIC, gender, and address '
            'with your private citizen account. '
            'Your password is handled by Supabase Auth. '
            'You’ll need to verify your email before entering the app.',
          ),
        ),
        actions: [
          TextButton(
            style: authTextButtonStyle(),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: AuthLayout(
        title: _step == 0 ? 'Make yourself heard' : 'A little about you',
        description: _step == 0
            ? 'Create your account to report and follow local issues.'
            : 'Add your citizen details to complete your registration. All fields are required.',
        onBack: _leave,
        backEnabled: !_busy,
        children: [
          Semantics(
            label: 'Registration step ${_step + 1} of 2: '
                '${_step == 0 ? 'Account details' : 'Citizen details'}',
            child: Row(
              children: [
                Expanded(
                  child: _StepLabel(
                    number: '1',
                    label: 'Account',
                    active: _step == 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StepLabel(
                    number: '2',
                    label: 'Citizen details',
                    active: _step == 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) AuthMessage(message: _error!),
          AutofillGroup(
            child: IndexedStack(
              index: _step,
              sizing: StackFit.loose,
              children: [
                // Visibility avoids reserving the height of the longer step.
                Visibility(
                  visible: _step == 0,
                  maintainState: true,
                  child: Form(
                    key: _accountForm,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthField(
                          controller: _name,
                          label: 'Full name',
                          icon: Icons.person_outline,
                          autofillHints: const [AutofillHints.name],
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().length < 3) {
                              return 'Enter your full name (at least 3 characters).';
                            }
                            if (value.trim().length > 100) {
                              return 'Use 100 characters or fewer.';
                            }
                            return null;
                          },
                          enabled: !_locked,
                        ),
                        AuthField(
                          controller: _email,
                          label: 'Email address',
                          icon: Icons.alternate_email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.newUsername,
                            AutofillHints.email,
                          ],
                          validator: validateAuthEmail,
                          enabled: !_locked,
                        ),
                        AuthField(
                          controller: _password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          password: true,
                          autofillHints: const [AutofillHints.newPassword],
                          helperText:
                              'Use at least 8 characters, including uppercase '
                              'and lowercase letters, a number, and a symbol.',
                          validator: validateNewAuthPassword,
                          enabled: !_locked,
                        ),
                        AuthField(
                          controller: _confirmation,
                          label: 'Confirm password',
                          icon: Icons.lock_outline,
                          password: true,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (value) => value == null || value.isEmpty
                              ? 'Confirm your password.'
                              : value != _password.text
                                  ? 'Your passwords don’t match.'
                                  : null,
                          enabled: !_locked,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _continue(),
                        ),
                        AsyncButton(
                          label: 'Continue',
                          icon: Icons.arrow_forward_outlined,
                          onPressed: _locked ? null : _continue,
                        ),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: _step == 1,
                  maintainState: true,
                  child: Form(
                    key: _identityForm,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthField(
                          controller: _phone,
                          label: 'Phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          helperText: 'International format: +923001234567',
                          validator: (value) => value == null ||
                                  !RegExp(r'^\+923[0-9]{9}$')
                                      .hasMatch(value.trim())
                              ? 'Enter a Pakistani mobile number, e.g. +923001234567.'
                              : null,
                          enabled: !_locked,
                        ),
                        AuthField(
                          controller: _cnic,
                          label: 'CNIC',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.text,
                          helperText: 'Format: 12345-1234567-1',
                          validator: (value) => value == null ||
                                  !RegExp(r'^\d{5}-\d{7}-\d$')
                                      .hasMatch(value.trim())
                              ? 'Enter your CNIC in the format 12345-1234567-1.'
                              : null,
                          enabled: !_locked,
                        ),
                        AuthField(
                          controller: _address,
                          label: 'Location / address',
                          icon: Icons.location_on_outlined,
                          keyboardType: TextInputType.streetAddress,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [
                            AutofillHints.fullStreetAddress,
                          ],
                          helperText:
                              'House or apartment, street, area, and city',
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            return length < 3 || length > 250
                                ? 'Use an address between 3 and 250 characters.'
                                : null;
                          },
                          enabled: !_locked,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          items: const ['Male', 'Female', 'Other']
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                          onChanged: _locked
                              ? null
                              : (value) => setState(() => _gender = value),
                          validator: (value) =>
                              value == null ? 'Select your gender.' : null,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                            'Add a profile photo from Account after verifying your email.'),
                        const SizedBox(height: 20),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _consent,
                          onChanged: _locked
                              ? null
                              : (value) =>
                                  setState(() => _consent = value ?? false),
                          title: const Text(
                            'I consent to storing my identity and contact details for my citizen account.',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: authTextButtonStyle(),
                            onPressed: _showDataDetails,
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: const Text(
                              'About your registration details',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AsyncButton(
                          label: 'Create account',
                          icon: Icons.arrow_forward_outlined,
                          onPressed: _busy ? null : _register,
                          isLoading: _busy,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: authTextButtonStyle(),
                          onPressed: _busy ? null : _leave,
                          child: const Text('Back to account details'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                style: authTextButtonStyle(),
                onPressed: _busy
                    ? null
                    : () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.number,
    required this.label,
    required this.active,
  });
  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: active ? 3 : 1,
          ),
        ),
      ),
      child: Text(
        '$number  $label',
        style: theme.textTheme.labelLarge?.copyWith(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
