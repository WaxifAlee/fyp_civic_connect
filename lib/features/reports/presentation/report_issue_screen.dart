import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/app/app_shell.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:fyp_civic_connect/features/reports/domain/report_filters.dart';
import 'package:fyp_civic_connect/features/reports/presentation/map_location_picker.dart';
import 'package:fyp_civic_connect/features/reports/widgets/report_image_picker.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key, this.submission});

  final ReportSubmissionService? submission;

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _photosKey = GlobalKey<FormFieldState<List<XFile>>>();
  final _feedbackKey = GlobalKey();
  final _feedbackFocus = FocusNode();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _locationText = TextEditingController();
  late final _submission = widget.submission ?? ReportSubmissionService();
  List<XFile> _images = const [];
  String? _category;
  LatLng? _location;
  String? _error;
  bool _submitting = false;
  bool _readingPhotos = false;
  bool _validate = false;
  double _progress = 0;
  String _progressMessage = 'Preparing your report…';
  ReportSubmissionResult? _result;
  int? _pendingCount;
  bool _recovering = false;
  String? _recoveryMessage;
  String? _recoveryError;

  static const _categoryDescriptions = <String, String>{
    'Municipal Corportaion': 'Waste, drainage & sanitation',
    'Police Department': 'Safety & public order',
    'Fire & Emergency Services': 'Fire hazards & public safety',
    'Electricity & Gas Department': 'Power supply & utility faults',
    'Public Works Department (PWD)': 'Roads, footpaths & public buildings',
  };

  bool get _preview => AppSession.instance.isPreview;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    try {
      final count = await _submission.pendingSubmissionCount();
      if (mounted) {
        setState(() {
          _pendingCount = count;
          _recoveryError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recoveryError = error is ReportSubmissionException
              ? error.message
              : 'Saved submissions could not be checked. Please retry.';
        });
      }
    }
  }

  Future<void> _recoverSaved() async {
    if (_recovering || _submitting) return;
    setState(() {
      _recovering = true;
      _recoveryError = null;
      _recoveryMessage = null;
    });
    try {
      final recovered = await _submission.recoverPending();
      if (!mounted) return;
      final message = recovered == null
          ? 'No saved submissions remain. Your current draft is still here.'
          : 'Earlier report submitted as ${recovered.reportCode}. '
              'Your current draft is still here.';
      setState(() => _recoveryMessage = message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on DeletedReportSubmissionException catch (error) {
      if (mounted) setState(() => _recoveryMessage = error.message);
    } on ReportSubmissionException catch (error) {
      if (mounted) setState(() => _recoveryError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _recoveryError =
            'Saved submissions could not be checked. Please retry.');
      }
    } finally {
      // Refresh the count without clearing feedback from the recovery attempt.
      final error = _recoveryError;
      await _refreshPending();
      if (mounted) {
        setState(() {
          _recoveryError ??= error;
          _recovering = false;
        });
      }
    }
  }

  Widget _savedSubmissions() {
    final count = _pendingCount;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            title: 'Saved submissions',
            subtitle:
                'Check an earlier report while keeping your current draft.',
          ),
          const SizedBox(height: 16),
          if (count == null && _recoveryError == null)
            const Text('Checking saved submissions…'),
          if (count != null && count > 0)
            Text(
                '$count saved ${count == 1 ? 'submission' : 'submissions'} to check.'),
          if (_recoveryMessage != null)
            Semantics(liveRegion: true, child: Text(_recoveryMessage!)),
          if (_recoveryError != null)
            Semantics(
              liveRegion: true,
              child: Text(_recoveryError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if ((count ?? 0) > 0 || _recoveryError != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting || _recovering ? null : _recoverSaved,
              icon: const Icon(Icons.restore_outlined),
              label: Text(_recovering
                  ? 'Checking saved submission…'
                  : 'Recover saved submission'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _locationText.dispose();
    _feedbackFocus.dispose();
    super.dispose();
  }

  void _announceError(String message) {
    setState(() => _error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feedbackFocus.requestFocus();
      final feedbackContext = _feedbackKey.currentContext;
      if (feedbackContext != null) {
        Scrollable.ensureVisible(
          feedbackContext,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          alignment: 0.15,
        );
      }
    });
  }

  Future<void> _chooseLocation() async {
    if (_submitting) return;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            MapLocationPicker(initialLocation: _location, isPreview: _preview),
      ),
    );
    if (!mounted || picked == null) return;
    final error = FatehJangArea.validate(picked.latitude, picked.longitude);
    if (error != null) {
      _announceError(error);
      return;
    }
    setState(() {
      _location = picked;
      _locationText.text = '${picked.latitude}, ${picked.longitude}';
    });
    if (_validate) _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (_submitting || _readingPhotos || _recovering) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _validate = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) {
      _announceError(
        'Check the highlighted fields below. Add 1–3 photos '
        'and choose an issue location inside Fateh Jang.',
      );
      return;
    }
    final preview = _preview;
    if (!preview && !SupabaseService.isConfigured) {
      _announceError(
        'Photo uploads are not set up yet. Your draft is safe '
        'here. Ask the CivicConnect administrator to enable uploads, '
        'then try again.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _progress = 0;
      _progressMessage =
          preview ? 'Checking your preview…' : 'Preparing your report…';
    });
    try {
      final ReportSubmissionResult result;
      if (preview) {
        // Deliberately local: no Supabase, counters or production ID.
        // Re-read the selected bytes to catch expired or removed local files.
        for (final image in _images) {
          await ReportSubmissionService.readPhoto(image);
        }
        result = const ReportSubmissionResult(
          reportCode: 'DEMO-REPORT',
          isPreview: true,
        );
      } else {
        result = await _submission.submit(
          title: _title.text,
          description: _description.text,
          category: _category!,
          location: _location!,
          images: List<XFile>.of(_images),
          onProgress: (progress, message) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
              _progressMessage = message;
            });
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _progress = 1;
      });
    } on ReportSubmissionException catch (error) {
      if (mounted) _announceError(error.message);
    } catch (_) {
      if (mounted) {
        _announceError(
          'Your report could not be completed. Check your '
          'connection and try again. Your details and photos are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      await _refreshPending();
    }
  }

  void _resetDraft() {
    setState(() {
      _result = null;
      _title.clear();
      _description.clear();
      _locationText.clear();
      _category = null;
      _location = null;
      _images = const [];
      _error = null;
      _validate = false;
      _progress = 0;
    });
  }

  Widget _categoryChooser() {
    return FormField<String>(
      initialValue: _category,
      validator: (_) => _category == null ? 'Choose a department.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Department', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const Text('Choose the team best placed to help.'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final category in reportCategories)
                    SizedBox(
                      width: width,
                      child: _CategoryTile(
                        category: category,
                        description: _categoryDescriptions[category.value]!,
                        selected: _category == category.value,
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() => _category = category.value);
                                field.didChange(category.value);
                              },
                      ),
                    ),
                ],
              );
            },
          ),
          if (field.hasError) ...[
            const SizedBox(height: 8),
            Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _details() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            title: 'Details',
            subtitle: 'A clear description helps the right team respond.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _title,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLength: ReportSubmissionService.maxTitleLength,
            decoration: const InputDecoration(
              labelText: 'Issue title',
              hintText: 'e.g. Damaged streetlight on Main Road',
              helperText:
                  'Use a short, specific title (at least 5 characters).',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if ((value?.trim().length ?? 0) < 5) {
                return 'Describe the issue in at least 5 characters.';
              }
              if (value!.trim().length >
                  ReportSubmissionService.maxTitleLength) {
                return 'Keep the title within 120 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _description,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            minLines: 4,
            maxLines: 8,
            maxLength: ReportSubmissionService.maxDescriptionLength,
            decoration: const InputDecoration(
              labelText: 'What is happening?',
              alignLabelWithHint: true,
              hintText: 'Describe the problem, when you noticed it, and a '
                  'nearby landmark.',
              helperText: 'Include useful details (at least 20 characters).',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if ((value?.trim().length ?? 0) < 20) {
                return 'Add a little more detail (at least 20 characters).';
              }
              if (value!.trim().length >
                  ReportSubmissionService.maxDescriptionLength) {
                return 'Keep the description within 2,000 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _categoryChooser(),
        ],
      ),
    );
  }

  Widget _photos() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            title: 'Photos',
            subtitle: 'Give the team a useful view of the issue.',
          ),
          const SizedBox(height: 24),
          FormField<List<XFile>>(
            key: _photosKey,
            initialValue: _images,
            validator: (_) => _images.isEmpty ||
                    _images.length > ReportSubmissionService.maxImages
                ? 'Add between 1 and 3 photos to continue.'
                : null,
            builder: (field) => ReportImagePicker(
              images: _images,
              enabled: !_submitting,
              errorText: field.errorText,
              onBusyChanged: (busy) {
                if (mounted) setState(() => _readingPhotos = busy);
              },
              onChanged: (images) {
                setState(() => _images = images);
                field.didChange(images);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationSection() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            title: 'Location',
            subtitle: 'Where is the issue? We currently serve Fateh Jang.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _locationText,
            enabled: !_submitting,
            readOnly: true,
            onTap: _chooseLocation,
            decoration: InputDecoration(
              labelText: 'Issue coordinates',
              hintText: 'Choose a location',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Choose issue location',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _submitting ? null : _chooseLocation,
                icon: const Icon(Icons.edit_location_alt_outlined),
              ),
            ),
            validator: (_) => _location == null
                ? 'Choose the issue location to continue.'
                : FatehJangArea.validate(
                    _location!.latitude,
                    _location!.longitude,
                  ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _chooseLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _location == null ? 'Choose location' : 'Change location',
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success(ReportSubmissionResult result) {
    final colors = Theme.of(context).colorScheme;
    final preview = result.isPreview;
    return Entrance(
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  preview ? Icons.visibility_outlined : Icons.task_alt_outlined,
                  color: colors.onPrimaryContainer,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                preview
                    ? 'Preview complete · not submitted'
                    : 'Report submitted',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              preview
                  ? 'This is a local simulation. No report or photos have '
                      'been sent, and no production reference was created.'
                  : 'Your report and photos have been saved. You can follow '
                      'its progress in My reports.',
            ),
            const SizedBox(height: 24),
            Text(
              preview ? 'Sample reference · not submitted' : 'Your report code',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SelectableText(
              result.reportCode,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              _title.text.trim(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(categoryLabel(_category)),
            const SizedBox(height: 8),
            Text(
              '${_images.length} '
              '${_images.length == 1 ? 'photo' : 'photos'} · Fateh Jang',
            ),
            if (!preview) ...[
              const SizedBox(height: 8),
              Text('Status: ${ReportStatus.pending.label}'),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/my_reports'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(
                    preview ? 'Explore sample reports' : 'My reports',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: preview
                      ? () => setState(() => _result = null)
                      : _resetDraft,
                  icon: Icon(
                    preview ? Icons.edit_outlined : Icons.add_outlined,
                  ),
                  label: Text(
                    preview ? 'Edit this preview' : 'Report another issue',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSession.instance,
      builder: (context, _) => AppShell(
        currentIndex: 2,
        child: CivicPage(
          title: 'Report an issue',
          description:
              'Help improve your neighbourhood, one clear report at a time.',
          maxWidth: 960,
          children: [
            if (_result != null)
              _success(_result!)
            else ...[
              if (_preview) ...[
                const _ReportNotice(
                  icon: Icons.visibility_outlined,
                  title: 'Preview mode',
                  message: 'Try the complete form with your own photos. '
                      'The confirmation is simulated locally; nothing is submitted.',
                ),
              ] else if (!SupabaseService.isConfigured) ...[
                const _ReportNotice(
                  icon: Icons.cloud_off_outlined,
                  title: 'Photo uploads are not available yet',
                  message:
                      'You can prepare a report here. Ask the CivicConnect '
                      'administrator to enable photo uploads before submitting.',
                ),
              ],
              if (!_preview &&
                  (_pendingCount == null ||
                      _pendingCount! > 0 ||
                      _recoveryMessage != null ||
                      _recoveryError != null))
                _savedSubmissions(),
              Form(
                key: _formKey,
                autovalidateMode: _validate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Focus(
                        key: _feedbackKey,
                        focusNode: _feedbackFocus,
                        child: _ReportNotice(
                          icon: Icons.error_outline,
                          title: 'Your report needs attention',
                          message: _error!,
                          isError: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _details(),
                    const SizedBox(height: 24),
                    _photos(),
                    const SizedBox(height: 24),
                    _locationSection(),
                    const SizedBox(height: 24),
                    if (_submitting) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(_progressMessage),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _preview ? null : _progress,
                        semanticsLabel: _progressMessage,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      _preview
                          ? 'Preview shows how confirmation looks. It does '
                              'not send a report.'
                          : 'Your report’s description, photos and location '
                              'will be visible to the community. Leave out '
                              'private information.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    AsyncButton(
                      label:
                          _preview ? 'Preview confirmation' : 'Submit report',
                      icon: _preview
                          ? Icons.visibility_outlined
                          : Icons.send_outlined,
                      isLoading: _submitting,
                      onPressed: _submitting || _readingPhotos || _recovering
                          ? null
                          : _submit,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.description,
    required this.selected,
    required this.onPressed,
  });

  final ({String value, String label, IconData icon}) category;
  final String description;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor:
              selected ? colors.onPrimaryContainer : colors.onSurface,
          backgroundColor: selected ? colors.primaryContainer : colors.surface,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
          padding: const EdgeInsets.all(16),
          minimumSize: const Size(48, 72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(category.icon, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Icon(
                selected
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportNotice extends StatelessWidget {
  const _ReportNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        isError ? colors.onErrorContainer : colors.onPrimaryContainer;
    return Semantics(
      liveRegion: isError,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: foreground)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: foreground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
