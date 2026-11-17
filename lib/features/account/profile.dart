import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/app/app_shell.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/core/widgets/leave_guard.dart';
import 'package:fyp_civic_connect/core/widgets/form_validation.dart';
import 'package:fyp_civic_connect/models/citizen_user.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:fyp_civic_connect/services/citizen_account_service.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';
import 'package:fyp_civic_connect/services/storage_paths.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:fyp_civic_connect/utils/validators.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.account = const CitizenAccountService()});
  final CitizenAccountService account;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  CitizenUser? _citizen;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _signingOut = false;
  bool _uploadingPhoto = false;
  String? _loadError;
  String? _saveError;

  bool get _isPreview => AppSession.instance.isPreview;
  bool get _hasChanges =>
      _editing &&
      (_name.text != (_citizen?.fullName ?? '') ||
          _phone.text != (_citizen?.phone ?? '') ||
          _location.text != (_citizen?.location ?? ''));

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (_isPreview) {
        // This record belongs only to this screen, never globalCitizenUser.
        _citizen = CitizenUser(
          uid: 'demo-citizen',
          fullName: 'Ayesha Khan',
          email: 'ayesha@example.com',
          location: 'Fateh Jang',
          phone: '+923001234567',
          displayPicture: null,
          cnic: null,
          gender: null,
          joinDate: null,
        );
      } else {
        final userId = widget.account.userId;
        if (userId == null) {
          throw StateError('Sign in to view your account details.');
        }
        final profile = await widget.account.load();
        if (!mounted || _isPreview || widget.account.userId != userId) return;
        _citizen = profile;
        if (_citizen == null) {
          throw StateError('Your account details could not be loaded.');
        }
        _citizen!.uid = userId;
      }
      if (!mounted) return;
      _resetFields();
    } on StateError catch (error) {
      if (mounted) _loadError = error.message.toString();
    } catch (_) {
      if (mounted) {
        _loadError = 'We couldn’t load your account. Check your connection and '
            'try again.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetFields() {
    _name.text = _citizen?.fullName ?? '';
    _phone.text = _citizen?.phone ?? '';
    _location.text = _citizen?.location ?? '';
  }

  Future<void> _changePhoto() async {
    if (_isPreview || _uploadingPhoto || _saving || _signingOut || _editing) {
      return;
    }
    final user = SupabaseService.client.auth.currentUser;
    if (user == null || user.id != _citizen?.uid) return;
    final previousPath = ownedAvatarStoragePath(
        _citizen?.displayPicture, SupabaseService.url, user.id);
    setState(() => _uploadingPhoto = true);
    String? uploadedPath;
    var profileWriteStarted = false;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted || _isPreview) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const ReportSubmissionException(
            'Choose a profile photo of 5 MB or smaller.');
      }
      final photo = await ReportSubmissionService.readPhoto(file);
      if (!mounted ||
          _isPreview ||
          SupabaseService.client.auth.currentUser?.id != user.id) {
        return;
      }
      uploadedPath = '${user.id}/${const Uuid().v4()}.${photo.extension}';
      final storage = SupabaseService.client.storage.from('profile-pictures');
      await storage.uploadBinary(uploadedPath, photo.bytes,
          fileOptions: FileOptions(contentType: photo.contentType));
      if (!mounted ||
          _isPreview ||
          SupabaseService.client.auth.currentUser?.id != user.id) {
        return;
      }
      profileWriteStarted = true;
      await updateCitizenAvatar(userId: user.id, profilePicture: uploadedPath);
      if (!mounted ||
          _isPreview ||
          SupabaseService.client.auth.currentUser?.id != user.id) {
        return;
      }
      setState(() => _citizen = globalCitizenUser);
      if (previousPath != null && previousPath != uploadedPath) {
        try {
          await storage.remove([previousPath]);
        } catch (_) {
          // The new reference is committed; old-image cleanup can be retried later.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your profile photo has been updated.')));
    } catch (error) {
      // Once the profile write starts, a lost response may still have saved it.
      // Keep that object rather than leaving a committed profile with no image.
      if (uploadedPath != null &&
          !profileWriteStarted &&
          SupabaseService.client.auth.currentUser?.id == user.id) {
        try {
          await SupabaseService.client.storage
              .from('profile-pictures')
              .remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) {
        if (profileWriteStarted) _invalidateProfile();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is ReportSubmissionException
                ? error.message
                : 'We couldn’t confirm the photo update. Refresh your account before trying again.')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _invalidateProfile() {
    globalCitizenUser = null;
    _citizen = null;
    _editing = false;
    _loadError =
        'The account update could not be confirmed. Refresh your account '
        'to load the saved details before making more changes.';
  }

  Future<void> _saveProfile() async {
    if (_saving ||
        _uploadingPhoto ||
        !validateAndReveal(_formKey.currentState)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final location = _location.text.trim();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (!_isPreview) {
        final userId = widget.account.userId;
        if (userId == null || userId != _citizen?.uid) {
          throw StateError('Your session has ended. Sign in again to save.');
        }
        await widget.account
            .save(fullName: name, phone: phone, location: location);
        if (!mounted || _isPreview || widget.account.userId != userId) return;
      }
      if (!mounted) return;
      _citizen!
        ..fullName = name
        ..phone = phone
        ..location = location;
      if (!_isPreview) globalCitizenUser = _citizen;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPreview
                ? 'Demo details updated for this preview only.'
                : 'Your account details have been saved.',
          ),
        ),
      );
    } on StateError {
      if (mounted) setState(_invalidateProfile);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          if (!['23505', '23514', '42501'].contains(error.code)) {
            _invalidateProfile();
            return;
          }
          _saveError = error.code == '23505'
              ? 'This phone number is already linked to an account.'
              : error.code == '42501'
                  ? 'You don’t have permission to update this account. Sign in '
                      'again and retry.'
                  : 'We couldn’t save your changes. Check your connection and '
                      'try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(_invalidateProfile);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final preview = _isPreview;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(preview ? 'Leave preview?' : 'Sign out?'),
        content: Text(
          preview
              ? 'Your demo edits will be discarded.'
              : _hasChanges
                  ? 'Your unsaved account changes will be discarded. You can sign in again to view your reports and account.'
                  : 'You can sign in again to view your reports and account.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(preview ? 'Leave preview' : 'Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      if (preview) {
        AppSession.instance.leavePreview();
      } else if (SupabaseService.isConfigured) {
        await SupabaseService.client.auth.signOut();
      }
      globalCitizenUser = null;
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(preview ? '/' : '/login', (_) => false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We couldn’t sign you out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reporting with care',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Use CivicConnect for non-emergency local issues, '
                  'such as damaged roads, waste, or street lighting. '
                  'If there is immediate danger, contact local emergency '
                  'services directly.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Include a clear description and location. Avoid '
                  'including CNIC numbers, private contact details, or '
                  'identifiable people in public report photos.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Follow the status of your submissions in My Reports.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([_name, _phone, _location]),
        builder: (context, _) => LeaveGuard(
            dirty: _hasChanges,
            busy: _saving || _uploadingPhoto || _signingOut,
            title: 'Discard account changes?',
            message:
                'Your account changes have not been saved. Leaving will discard these edits.',
            builder: (context, confirmLeave) => AppShell(
                  onBeforeLeave: confirmLeave,
                  currentIndex: 4,
                  child: CivicPage(
                    title: 'Your account',
                    description:
                        'Manage your details and make CivicConnect feel like home.',
                    children: [
                      if (_isPreview)
                        const _AccountNotice(
                          icon: Icons.visibility_outlined,
                          message:
                              'Preview mode · Demo citizen. Changes stay in this '
                              'preview and never update a real account.',
                        ),
                      if (_loading)
                        const AppPanel(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading your account…'),
                              ],
                            ),
                          ),
                        )
                      else if (_loadError != null)
                        AppPanel(
                          child: EmptyState(
                            icon: Icons.person_outline,
                            title: 'Account unavailable',
                            message: _loadError!,
                            actionLabel: 'Try again',
                            onAction: _loadProfile,
                          ),
                        )
                      else ...[
                        Entrance(child: _overview(context)),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final details = _details(context);
                            final preferences = _preferences(context);
                            final largeText =
                                MediaQuery.textScalerOf(context).scale(16) > 22;
                            if (constraints.maxWidth < 840 || largeText) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  details,
                                  const SizedBox(height: 24),
                                  preferences,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: details),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: preferences),
                              ],
                            );
                          },
                        ),
                      ],
                      AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeading(
                              title: 'Your session',
                              subtitle:
                                  'Keep your account safe on shared devices.',
                            ),
                            const SizedBox(height: 16),
                            AsyncButton(
                              label: _isPreview ? 'Leave preview' : 'Sign out',
                              icon: Icons.logout_outlined,
                              isLoading: _signingOut,
                              onPressed:
                                  _saving || _signingOut || _uploadingPhoto
                                      ? null
                                      : _confirmSignOut,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )));
  }

  Widget _overview(BuildContext context) {
    final theme = Theme.of(context);
    final name = _display(_citizen?.fullName, fallback: 'Citizen');
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(_display(_citizen?.email), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Text(
          _isPreview ? 'Demo citizen account' : 'Citizen account',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        if (!_isPreview) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed:
                _uploadingPhoto || _saving || _editing ? null : _changePhoto,
            icon: _uploadingPhoto
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined, size: 20),
            label: Text(_uploadingPhoto ? 'Updating photo…' : 'Change photo'),
          ),
          Text('JPG, PNG or WebP · Up to 5 MB',
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
    return AppPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avatar = _CitizenAvatar(
            name: name,
            // Preview never loads remote media.
            url: _isPreview ? null : _citizen?.displayPicture,
          );
          if (constraints.maxWidth < 440 ||
              MediaQuery.textScalerOf(context).scale(16) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 16), identity],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: identity),
            ],
          );
        },
      ),
    );
  }

  Widget _details(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Personal details',
            subtitle: 'Keep your name and contact information up to date.',
          ),
          const SizedBox(height: 16),
          if (_editing) ...[
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AutofillGroup(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                        errorMaxLines: 4,
                      ),
                      autofillHints: const [AutofillHints.name],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          Validators.validateName(value?.trim()),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phone,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        helperText: 'International format: +923001234567',
                        helperMaxLines: 3,
                        prefixIcon: Icon(Icons.phone_outlined),
                        errorMaxLines: 4,
                      ),
                      autofillHints: const [AutofillHints.telephoneNumber],
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          Validators.validatePhone(value?.trim()),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _location,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Location / address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        errorMaxLines: 4,
                      ),
                      autofillHints: const [AutofillHints.fullStreetAddress],
                      keyboardType: TextInputType.streetAddress,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 3,
                      validator: (value) {
                        final address = value?.trim() ?? '';
                        if (address.isEmpty) {
                          return 'Enter your location or address';
                        }
                        if (address.length > 250) {
                          return 'Use 250 characters or fewer';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 16),
              _AccountNotice(
                icon: Icons.error_outline,
                message: _saveError!,
                isError: true,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AsyncButton(
                  label: _isPreview ? 'Save demo details' : 'Save changes',
                  icon: Icons.check_outlined,
                  isLoading: _saving,
                  onPressed: _saving || _signingOut ? null : _saveProfile,
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _resetFields();
                            _saveError = null;
                            _editing = false;
                          }),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ] else ...[
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Full name',
              value: _display(_citizen?.fullName),
            ),
            _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Phone number',
              value: _display(_citizen?.phone),
            ),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: _display(_citizen?.location),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _signingOut || _uploadingPhoto
                  ? null
                  : () => setState(() {
                        _resetFields();
                        _editing = true;
                      }),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit details'),
            ),
            const SizedBox(height: 24),
          ],
          const Divider(),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'Email · read only',
            value: _display(_citizen?.email),
          ),
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'CNIC · read only',
            value:
                _isPreview ? 'Not included in demo' : _display(_citizen?.cnic),
          ),
          if ((_citizen?.gender ?? '').trim().isNotEmpty)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Gender',
              value: _citizen!.gender!,
            ),
          if ((_citizen?.joinDate ?? '').trim().isNotEmpty)
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Joined',
              value: _citizen!.joinDate!,
            ),
        ],
      ),
    );
  }

  Widget _preferences(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                title: 'Appearance',
                subtitle: 'Choose a theme that works for you.',
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: AppSession.instance,
                builder: (context, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const {
                      ThemeMode.system: 'System',
                      ThemeMode.light: 'Light',
                      ThemeMode.dark: 'Dark',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: AppSession.instance.themeMode == entry.key,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        onSelected: (_) =>
                            AppSession.instance.setThemeMode(entry.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'System follows your device’s light or dark setting.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppPanel(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SectionHeading(title: 'Security & support'),
              ),
              const SizedBox(height: 8),
              _AccountAction(
                icon: Icons.lock_outline,
                title: 'Change password',
                subtitle: 'Protect access to your account',
                onTap: () => Navigator.pushNamed(context, '/change_password'),
              ),
              _AccountAction(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'View your notifications',
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
              _AccountAction(
                icon: Icons.help_outline,
                title: 'Reporting help',
                subtitle: 'What to report and how to stay safe',
                onTap: _showHelp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _display(String? value, {String fallback = 'Not provided'}) {
  return value == null || value.trim().isEmpty ? fallback : value.trim();
}

class _CitizenAvatar extends StatelessWidget {
  const _CitizenAvatar({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    final fallback = Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initials,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: colors.onPrimaryContainer),
          ),
        ),
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    final hasNetworkImage = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return Semantics(
      image: true,
      label: 'Profile picture for $name',
      child: ExcludeSemantics(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasNetworkImage
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ExcludeSemantics(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

class _AccountNotice extends StatelessWidget {
  const _AccountNotice({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                color: isError
                    ? colors.onErrorContainer
                    : colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isError
                          ? colors.onErrorContainer
                          : colors.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
