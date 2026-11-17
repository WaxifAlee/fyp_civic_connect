import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:image_picker/image_picker.dart';

/// Controlled photo selection. All reads and previews work without dart:io.
class ReportImagePicker extends StatefulWidget {
  const ReportImagePicker({
    super.key,
    required this.images,
    required this.onChanged,
    this.onBusyChanged,
    this.enabled = true,
    this.errorText,
  });

  final List<XFile> images;
  final ValueChanged<List<XFile>> onChanged;
  final ValueChanged<bool>? onBusyChanged;
  final bool enabled;
  final String? errorText;

  @override
  State<ReportImagePicker> createState() => _ReportImagePickerState();
}

class _ReportImagePickerState extends State<ReportImagePicker> {
  final _picker = ImagePicker();
  final _previews = <XFile, Future<ReportPhoto>>{};
  bool _busy = false;
  String? _error;

  bool get _canEdit => widget.enabled && !_busy;

  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void didUpdateWidget(covariant ReportImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previews.removeWhere((file, _) => !widget.images.contains(file));
    if (widget.images.isEmpty && oldWidget.images.isNotEmpty) _error = null;
  }

  Future<void> _pick({bool camera = false}) async {
    if (!_canEdit ||
        widget.images.length >= ReportSubmissionService.maxImages) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final List<XFile> candidates;
      if (camera) {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2400,
          requestFullMetadata: false,
        );
        candidates = image == null ? <XFile>[] : <XFile>[image];
      } else {
        candidates = await _picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2400,
          requestFullMetadata: false,
        );
      }
      if (!mounted) return;
      final remaining =
          ReportSubmissionService.maxImages - widget.images.length;
      final next = List<XFile>.of(widget.images);
      final messages = <String>{};
      if (candidates.length > remaining) {
        messages.add(
          'You can attach up to 3 photos. Only the first '
          '$remaining selected ${remaining == 1 ? 'photo was' : 'photos were'} '
          'checked.',
        );
      }
      for (final file in candidates.take(remaining)) {
        try {
          final photo = await ReportSubmissionService.readPhoto(file);
          // Check actual decoding as well as file type and byte limits.
          final codec = await ui.instantiateImageCodec(
            photo.bytes,
            targetWidth: 480,
          );
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
          if (!mounted) return;
          _previews[file] = Future.value(photo);
          next.add(file);
        } on ReportSubmissionException catch (error) {
          messages.add(error.message);
        } catch (_) {
          messages.add(
            'A selected photo could not be read. Choose another '
            'JPG, PNG or WebP image.',
          );
        }
      }
      if (!mounted) return;
      widget.onChanged(List<XFile>.unmodifiable(next));
      setState(() => _error = messages.isEmpty ? null : messages.join('\n'));
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.code.contains('denied') ||
                  error.code.contains('access')
              ? 'Photo access was not granted. Allow access in your device '
                  'settings, then try again.'
              : 'The photo picker is unavailable. Try choosing photos again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The photo picker could not open. Try again or choose '
              'photos from another device.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  void _remove(XFile file) {
    if (!_canEdit) return;
    _previews.remove(file);
    setState(() => _error = null);
    widget.onChanged(
      List<XFile>.unmodifiable(widget.images.where((image) => image != file)),
    );
  }

  Widget _thumbnail(XFile file, int index) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: FutureBuilder<ReportPhoto>(
                future: _previews.putIfAbsent(
                  file,
                  () => ReportSubmissionService.readPhoto(file),
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ColoredBox(
                      color: colors.errorContainer,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          semanticLabel: 'Photo could not be loaded',
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Image.memory(
                    snapshot.data!.bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 480,
                    semanticLabel: 'Attached issue photo ${index + 1}',
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: colors.errorContainer,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          semanticLabel: 'Photo could not be loaded',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Photo ${index + 1}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TextButton.icon(
            onPressed: _canEdit ? () => _remove(file) : null,
            icon: const Icon(Icons.close_outlined, size: 20),
            label: const Text('Remove'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canAdd =
        _canEdit && widget.images.length < ReportSubmissionService.maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.images.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Show what needs attention',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add a clear view of the issue. Avoid including '
                  'faces or personal documents.',
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                _thumbnail(widget.images[i], i),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: canAdd ? () => _pick() : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                widget.images.isEmpty ? 'Choose photos' : 'Add photos',
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            if (_cameraAvailable)
              OutlinedButton.icon(
                onPressed: canAdd ? () => _pick(camera: true) : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
            Text('${widget.images.length} of 3 photos'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '1–3 photos required · JPG, PNG or WebP · Up to 8 MB each',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(semanticsLabel: 'Reading photos'),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: const Text('Checking your photos…'),
          ),
        ],
        if (_error != null || widget.errorText != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              [_error, widget.errorText].whereType<String>().join('\n'),
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ],
    );
  }
}
