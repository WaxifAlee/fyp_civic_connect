import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, Supabase;

import 'auth_fields.dart';
import 'auth_flow.dart';
import 'auth_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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
  Uint8List? _photo;
  String? _photoExtension;
  String? _uploadedPhoto;
  User? _createdUser;
  int _step = 0;
  bool _consent = false;
  bool _busy = false;
  bool _pickingPhoto = false;
  String? _error;

  bool get _locked => _busy || _createdUser != null;

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
    if (_busy || !_accountForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _pickPhoto() async {
    if (_busy || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const AccountSetupException(
          'Choose a profile photo smaller than 5 MB.',
        );
      }
      final bytes = await file.readAsBytes();
      final jpeg = bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      final png = bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
      if (!jpeg && !png) {
        throw const AccountSetupException(
          'Choose a JPEG or PNG profile photo.',
        );
      }
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _uploadedPhoto = null;
        _photoExtension = jpeg ? 'jpg' : 'png';
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<String?> _uploadPhoto(User user) async {
    if (_photo == null) return null;
    if (_uploadedPhoto != null) return _uploadedPhoto;
    final bucket = Supabase.instance.client.storage.from('profile-pictures');
    final path =
        '${user.uid}/${DateTime.now().microsecondsSinceEpoch}.$_photoExtension';
    await bucket.uploadBinary(
      path,
      _photo!,
      fileOptions: FileOptions(
        contentType: _photoExtension == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );
    _uploadedPhoto = bucket.getPublicUrl(path);
    return _uploadedPhoto;
  }

  Future<void> _register() async {
    if (_busy || _pickingPhoto || !_identityForm.currentState!.validate()) {
      return;
    }
    if (!_consent) {
      setState(
        () => _error = 'Confirm your consent to create your citizen account.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    var profileSaved = false;
    try {
      final firestore = FirebaseFirestore.instance;
      if (_photo != null && !SupabaseService.isConfigured) {
        throw const AccountSetupException(
          'Profile photo uploads are unavailable. Remove the optional photo '
          'to continue, or try again later.',
        );
      }
      if (_createdUser == null) {
        final phoneMatch = await firestore
            .collection('users')
            .where('phone', isEqualTo: _phone.text.trim())
            .limit(1)
            .get();
        final cnicMatch = await firestore
            .collection('users')
            .where('cnic', isEqualTo: _cnic.text.trim())
            .limit(1)
            .get();
        if (phoneMatch.docs.isNotEmpty || cnicMatch.docs.isNotEmpty) {
          throw const AccountSetupException(
            'These identity details are already associated with an account. '
            'Check your details, or sign in to your existing account.',
          );
        }
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        _createdUser = credential.user;
        if (_createdUser == null) {
          throw StateError('Missing newly created user');
        }
        AppSession.instance.leavePreview();
      }
      final user = _createdUser!;
      final photoUrl = await _uploadPhoto(user);
      final now = DateTime.now();
      // Keep the existing pending_users schema. Passwords stay exclusively in
      // Firebase Authentication, never in a citizen document.
      await firestore.collection('pending_users').doc(user.uid).set({
        'uid': user.uid,
        'full_name': _name.text.trim(),
        'locations': _address.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'role': 'citizen',
        'profile_picture': photoUrl,
        'created_at': now,
        'updated_at': now,
        'cnic': _cnic.text.trim(),
        'gender': _gender,
        'email_verified': false,
      });
      profileSaved = true;
      // Saving the profile is the registration boundary. A mail delivery error
      // can be recovered on the verification screen without creating a new user.
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Verification offers resend and does not falsely claim delivery.
      }
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/verification',
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final detail = friendlyAuthError(error);
        _error = _createdUser != null && !profileSaved
            ? 'Your sign-in was created, but your profile has not been saved. '
                'Keep this page open and retry to finish setup. $detail'
            : detail;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy || _pickingPhoto) return;
    if (_createdUser != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel account setup?'),
          content: const Text(
            'Your profile has not been saved. Cancelling will remove the '
            'sign-in created during this setup. You can also stay and retry.',
          ),
          actions: [
            TextButton(
              style: authTextButtonStyle(),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep setting up'),
            ),
            TextButton(
              style: authTextButtonStyle(),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel setup'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      setState(() => _busy = true);
      try {
        await _createdUser!.delete();
        _createdUser = null;
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
          (route) => false,
        );
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = 'Setup could not be cancelled. Your details are '
                'still on this page; retry saving or cancelling. ${friendlyAuthError(error)}',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else if (_step == 1) {
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
            'Registration saves your name, email, phone, CNIC, gender, address, '
            'and optional profile photo with your citizen account. '
            'Your password is handled by Firebase Authentication. '
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
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: AuthLayout(
        title: _step == 0 ? 'Make yourself heard' : 'A little about you',
        description: _step == 0
            ? 'Create your account to report and follow local issues.'
            : 'Add your citizen details to complete your registration. All fields are required unless marked optional.',
        onBack: _leave,
        backEnabled: !_busy && !_pickingPhoto,
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
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            if (value.length > 64) {
                              return 'Use 64 characters or fewer.';
                            }
                            if (!RegExp(r'[A-Z]').hasMatch(value) ||
                                !RegExp(r'[a-z]').hasMatch(value) ||
                                !RegExp(r'[0-9]').hasMatch(value) ||
                                !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
                              return 'Include uppercase and lowercase letters, a number, and a symbol.';
                            }
                            return null;
                          },
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
                          validator: (value) =>
                              requiredAuthValue(value, 'address'),
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
                        _photoPicker(theme),
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
                          label: _createdUser == null
                              ? 'Create account'
                              : 'Retry saving my profile',
                          icon: Icons.arrow_forward_outlined,
                          onPressed: _busy || _pickingPhoto ? null : _register,
                          isLoading: _busy,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: authTextButtonStyle(),
                          onPressed: _busy || _pickingPhoto ? null : _leave,
                          child: Text(
                            _createdUser == null
                                ? 'Back to account details'
                                : 'Cancel account setup',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_createdUser == null)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Already have an account?'),
                TextButton(
                  style: authTextButtonStyle(),
                  onPressed: _busy || _pickingPhoto
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

  Widget _photoPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile photo (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundImage: _photo == null ? null : MemoryImage(_photo!),
              child: _photo == null
                  ? const Icon(Icons.person_outline, size: 28)
                  : null,
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _busy || _pickingPhoto ? null : _pickPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _pickingPhoto
                    ? 'Opening photos…'
                    : _photo == null
                        ? 'Choose photo'
                        : 'Change photo',
              ),
            ),
            if (_photo != null)
              IconButton(
                tooltip: 'Remove profile photo',
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _photo = null;
                          _uploadedPhoto = null;
                          _photoExtension = null;
                        }),
                icon: const Icon(Icons.close_outlined),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('JPEG or PNG, up to 5 MB.', style: theme.textTheme.bodySmall),
      ],
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
