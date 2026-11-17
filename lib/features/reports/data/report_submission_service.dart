import 'dart:convert';
import 'dart:typed_data';

import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// The original service polygon, shared by GPS, map taps and manual entry.
abstract final class FatehJangArea {
  static const center = LatLng(33.55, 72.63);
  static const boundary = <LatLng>[
    LatLng(33.6013, 72.5843),
    LatLng(33.5765, 72.6912),
    LatLng(33.4857, 72.6903),
    LatLng(33.4701, 72.5750),
    LatLng(33.6013, 72.5843),
  ];

  /// Validate raw numbers before LatLng can normalize out-of-range values.
  static String? validate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Enter both latitude and longitude.';
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      return 'Latitude must be a number between −90 and 90.';
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      return 'Longitude must be a number between −180 and 180.';
    }
    if (!contains(LatLng(latitude, longitude))) {
      return 'Choose a location inside the Fateh Jang service area.';
    }
    return null;
  }

  static bool contains(LatLng point) {
    if (!point.latitude.isFinite || !point.longitude.isFinite) return false;
    var inside = false;
    for (var i = 0; i < boundary.length - 1; i++) {
      final a = boundary[i];
      final b = boundary[i + 1];
      final dx = b.longitude - a.longitude;
      final dy = b.latitude - a.latitude;
      final px = point.longitude - a.longitude;
      final py = point.latitude - a.latitude;
      // Include points on the perimeter, consistently across every entry path.
      final cross = dx * py - dy * px;
      final dot = px * dx + py * dy;
      if (cross.abs() <= 1e-10 && dot >= 0 && dot <= dx * dx + dy * dy) {
        return true;
      }
      if ((a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              dx * (point.latitude - a.latitude) / dy + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class ReportSubmissionException implements Exception {
  const ReportSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The earlier create completed, but the current form is a different draft.
/// Throwing keeps existing form callers out of their new-draft success flow.
class PreviousReportSubmissionException extends ReportSubmissionException {
  PreviousReportSubmissionException(this.reportCode)
      : super(
          'Your earlier report was submitted as $reportCode. '
          'Your changed draft has not been submitted and is still here. '
          'Submit again to send this draft.',
        );
  final String reportCode;
}

/// The server verified ownership of a request whose report was removed.
class DeletedReportSubmissionException extends ReportSubmissionException {
  const DeletedReportSubmissionException()
      : super(
            'Earlier report was removed; submit your current draft when ready.');
}

class ReportSubmissionResult {
  const ReportSubmissionResult({
    required this.reportCode,
    this.isPreview = false,
  });

  final String reportCode;
  final bool isPreview;
}

class ReportPhoto {
  const ReportPhoto({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

/// A byte-based upload path for both browser and native image pickers.
class ReportSubmissionService {
  ReportSubmissionService({ReportBackend? backend})
      : _backend = backend ?? ReportBackend();
  final ReportBackend _backend;
  static String _pendingPrefix(String uid) =>
      'reports.pending_submission.v2.$uid.';
  static String _pendingKey(String uid, String requestId) =>
      '${_pendingPrefix(uid)}$requestId';
  // Serialize across form/service instances within the application's isolate.
  static bool _submitting = false;
  static const maxImages = 3;
  static const maxImageBytes = 8 * 1024 * 1024;
  static const maxTitleLength = 120;
  static const maxDescriptionLength = 2000;

  // Keep the legacy category spelling in stored records and report counters.
  static const categoryPrefixes = <String, String>{
    'Municipal Corportaion': 'MC',
    'Police Department': 'PD',
    'Fire & Emergency Services': 'FE',
    'Electricity & Gas Department': 'EG',
    'Public Works Department (PWD)': 'PW',
  };

  static Future<ReportPhoto> readPhoto(XFile file) async {
    if (await file.length() > maxImageBytes) {
      throw const ReportSubmissionException(
        'Each photo must be 8 MB or smaller. Choose a smaller photo.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const ReportSubmissionException(
        'Each photo must contain an image and be 8 MB or smaller.',
      );
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return ReportPhoto(
        bytes: bytes,
        extension: 'jpg',
        contentType: 'image/jpeg',
      );
    }
    const pngHeader = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == pngHeader[i]).every((v) => v)) {
      return ReportPhoto(
        bytes: bytes,
        extension: 'png',
        contentType: 'image/png',
      );
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ReportPhoto(
        bytes: bytes,
        extension: 'webp',
        contentType: 'image/webp',
      );
    }
    throw const ReportSubmissionException(
      'Choose a JPG, PNG or WebP photo. Convert HEIC photos to JPG first.',
    );
  }

  Future<ReportSubmissionResult> submit({
    required String title,
    required String description,
    required String category,
    required LatLng location,
    required List<XFile> images,
    void Function(double progress, String message)? onProgress,
  }) async {
    // Preview must return before even reading an SDK-backed property.
    if (AppSession.instance.isPreview) {
      throw const ReportSubmissionException(
        'Preview reports stay on this device. Return to the form to preview it.',
      );
    }
    if (_submitting) {
      throw const ReportSubmissionException(
        'A report is already being submitted. Please wait for it to finish.',
      );
    }
    if (!_backend.isConfigured) {
      throw const ReportSubmissionException(
        'Reports are not set up yet. Your draft is still here.',
      );
    }
    final uid = _backend.verifiedUserId;
    if (uid == null) {
      throw const ReportSubmissionException(
        'Sign in with a verified account before submitting. Your draft is still here.',
      );
    }
    _submitting = true;
    final uploaded = <String>[];
    var pendingSaved = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      _checkSession(uid);
      final entries = await _pending(preferences, uid);
      final pending = entries.isEmpty ? null : entries.first;

      if (pending == null) {
        _validateDraft(title, description, category, location, images.length);
      }
      final photos = <ReportPhoto>[];
      String? draft;
      try {
        onProgress?.call(0.05, 'Checking your photos…');
        for (final image in images) {
          photos.add(await readPhoto(image));
          _checkSession(uid);
        }
        draft = _draft(title, description, category, location, photos);
      } on ReportSubmissionException {
        _checkSession(uid);
        if (pending == null) rethrow;
        // A changed/invalid current draft must not block recovery of the old one.
      } catch (_) {
        _checkSession(uid);
        if (pending == null) rethrow;
      }
      _checkSession(uid);
      if (pending != null) {
        onProgress?.call(0.85, 'Checking your earlier submission…');
        final result = await _confirm(preferences, pending, resume: true);
        if (draft != pending.draft) {
          throw PreviousReportSubmissionException(result.reportCode);
        }
        return result;
      }

      // Every photo has been validated before any upload starts.
      for (var i = 0; i < photos.length; i++) {
        _checkSession(uid);
        final photo = photos[i];
        final path = '$uid/${const Uuid().v4()}.${photo.extension}';
        uploaded.add(path); // Include uploads whose response may be lost.
        onProgress?.call(
          0.1 + 0.65 * i / photos.length,
          'Uploading photo ${i + 1} of ${photos.length}…',
        );
        _checkSession(uid);
        await _backend.upload(path, photo.bytes, photo.contentType);
        _checkSession(uid);
      }
      final requestId = const Uuid().v4();
      final next = _PendingReport(
        uid: uid,
        requestId: requestId,
        draft: draft!,
        payload: {
          'p_request_id': requestId,
          'p_title': title.trim(),
          'p_description': description.trim(),
          'p_category': category,
          'p_latitude': location.latitude,
          'p_longitude': location.longitude,
          'p_media_paths': List<String>.of(uploaded),
        },
      );
      _checkSession(uid);
      if (!await preferences.setString(
          _pendingKey(uid, requestId), next.encode())) {
        throw const ReportSubmissionException(
          'Your submission could not be saved on this device. Please try again.',
        );
      }
      pendingSaved = true;
      _checkSession(uid);
      onProgress?.call(0.85, 'Saving your report…');
      // Once persisted, keep photos even if session changes before dispatch.
      // After dispatch neither a null lookup nor a rejection proves an earlier
      // in-flight request cannot commit. Maintenance can remove true orphans.
      return await _confirm(preferences, next, resume: false);
    } catch (error) {
      if (!pendingSaved && uploaded.isNotEmpty && _sameSession(uid)) {
        try {
          _checkSession(uid);
          await _backend.remove(uploaded);
          _checkSession(uid);
        } catch (_) {
          // Pre-dispatch cleanup is best effort; never use a different account.
        }
      }
      if (error is ReportSubmissionException) rethrow;
      throw const ReportSubmissionException(
        'The report could not be completed. Check your connection and retry. '
        'Your draft is still here; any pending submission will be checked first.',
      );
    } finally {
      _submitting = false;
    }
  }

  /// Reload device storage so requests saved by other tabs become visible.
  Future<int> pendingSubmissionCount() async {
    if (AppSession.instance.isPreview || !_backend.isConfigured) return 0;
    final uid = _backend.verifiedUserId;
    if (uid == null) return 0;
    final preferences = await SharedPreferences.getInstance();
    _checkSession(uid);
    return (await _pending(preferences, uid)).length;
  }

  /// Recover one saved request without inspecting or changing the current form.
  Future<ReportSubmissionResult?> recoverPending() async {
    if (AppSession.instance.isPreview || !_backend.isConfigured) {
      throw const ReportSubmissionException(
          'Sign in to recover saved submissions.');
    }
    final uid = _backend.verifiedUserId;
    if (uid == null) {
      throw const ReportSubmissionException(
        'Sign in with a verified account to recover saved submissions.',
      );
    }
    if (_submitting) {
      throw const ReportSubmissionException(
        'A report is already being submitted. Please wait for it to finish.',
      );
    }
    _submitting = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _checkSession(uid);
      final entries = await _pending(preferences, uid);
      if (entries.isEmpty) return null;
      return await _confirm(preferences, entries.first, resume: true);
    } on ReportSubmissionException {
      rethrow;
    } catch (_) {
      throw const ReportSubmissionException(
        'Saved submissions could not be checked. Please retry. Your draft is still here.',
      );
    } finally {
      _submitting = false;
    }
  }

  Future<List<_PendingReport>> _pending(
    SharedPreferences preferences,
    String uid,
  ) async {
    _checkSession(uid);
    await preferences.reload();
    _checkSession(uid);
    // Copy the old UID record before retiring it. Each v2 entry owns its key,
    // so confirmation in one tab cannot erase another tab's request.
    final legacyKey = 'reports.pending_submission.v1.$uid';
    final legacy = preferences.getString(legacyKey);
    if (legacy != null) {
      final pending = _PendingReport.decode(legacy);
      _checkOwner(pending, uid);
      final key = _pendingKey(uid, pending.requestId);
      if (!preferences.containsKey(key)) {
        if (!await preferences.setString(key, pending.encode())) {
          throw const ReportSubmissionException(
              'Saved submission migration failed. Please retry.');
        }
        _checkSession(uid);
      }
      await preferences.reload();
      _checkSession(uid);
      // Only retire the exact legacy record we copied.
      if (preferences.getString(legacyKey) == legacy) {
        if (!await preferences.remove(legacyKey)) {
          throw const ReportSubmissionException(
              'Saved submission migration failed. Please retry.');
        }
        _checkSession(uid);
      }
    }
    await preferences.reload();
    _checkSession(uid);
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(_pendingPrefix(uid)))
        .toList()
      ..sort();
    return [
      for (final key in keys)
        _decodeEntry(preferences.getString(key)!, key, uid),
    ];
  }

  _PendingReport _decodeEntry(String raw, String key, String uid) {
    final pending = _PendingReport.decode(raw);
    _checkOwner(pending, uid);
    if (key != _pendingKey(uid, pending.requestId)) {
      throw const ReportSubmissionException(
          'An earlier submission could not be read. Contact CivicConnect support before retrying.');
    }
    return pending;
  }

  void _checkOwner(_PendingReport pending, String uid) {
    if (pending.uid != uid) {
      throw const ReportSubmissionException(
        'An earlier submission belongs to another account. Sign in to that '
        'account to finish it. Your current draft is still here.',
      );
    }
  }

  Future<ReportSubmissionResult> _confirm(
    SharedPreferences preferences,
    _PendingReport pending, {
    required bool resume,
  }) async {
    try {
      final result = await (resume ? _resume(pending) : _send(pending));
      await _forget(preferences, pending);
      return result;
    } on DeletedReportSubmissionException {
      await _forget(preferences, pending);
      rethrow;
    }
  }

  static void _validateDraft(
    String title,
    String description,
    String category,
    LatLng location,
    int imageCount,
  ) {
    if (title.trim().length < 5 || title.trim().length > maxTitleLength) {
      throw const ReportSubmissionException(
        'Use a title between 5 and 120 characters.',
      );
    }
    if (description.trim().length < 20 ||
        description.trim().length > maxDescriptionLength) {
      throw const ReportSubmissionException(
        'Use a description between 20 and 2,000 characters.',
      );
    }
    if (!categoryPrefixes.containsKey(category)) {
      throw const ReportSubmissionException('Choose a department.');
    }
    final locationError = FatehJangArea.validate(
      location.latitude,
      location.longitude,
    );
    if (locationError != null) throw ReportSubmissionException(locationError);
    if (imageCount < 1 || imageCount > maxImages) {
      throw const ReportSubmissionException('Add between 1 and 3 photos.');
    }
  }

  static String _draft(
    String title,
    String description,
    String category,
    LatLng location,
    List<ReportPhoto> photos,
  ) =>
      jsonEncode({
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'latitude': location.latitude,
        'longitude': location.longitude,
        // UUID v5 provides a stable content fingerprint using the existing uuid
        // dependency, without persisting image bytes or ephemeral picker paths.
        'photos': photos
            .map(
              (photo) => const Uuid()
                  .v5(Namespace.url.value, base64Encode(photo.bytes)),
            )
            .toList(),
      });

  Future<ReportSubmissionResult> _resume(_PendingReport pending) async {
    final found = await _lookup(pending);
    if (found != null) return found;
    // A null lookup does NOT authorize cleanup or a fresh request UUID.
    return _send(pending);
  }

  Future<ReportSubmissionResult?> _lookup(_PendingReport pending) async {
    _checkSession(pending.uid);
    try {
      final response = await _backend.rpc('get_report_submission', {
        'p_request_id': pending.requestId,
      });
      _checkSession(pending.uid);
      if (response == null) return null;
      if (response is Map &&
          response['id'] == pending.requestId &&
          response['deleted'] == true &&
          response['images'] is List &&
          (response['images'] as List).isEmpty) {
        throw const DeletedReportSubmissionException();
      }
      if (response is! Map ||
          jsonEncode(response['images']) !=
              jsonEncode(pending.payload['p_media_paths'])) {
        throw const FormatException('Invalid submission response');
      }
      return _result(response, pending);
    } on DeletedReportSubmissionException {
      rethrow;
    } catch (error) {
      _checkSession(pending.uid);
      // The idempotent create remains safe when lookup is unavailable.
      return null;
    }
  }

  Future<ReportSubmissionResult> _send(_PendingReport pending) async {
    _checkSession(pending.uid);
    try {
      final response = await _backend.rpc('create_report', pending.payload);
      _checkSession(pending.uid);
      return _result(response, pending);
    } on DeletedReportSubmissionException {
      rethrow;
    } catch (error) {
      _checkSession(pending.uid);
      if (error is PostgrestException && error.code == 'P0002') {
        throw const DeletedReportSubmissionException();
      }
      final found = await _lookup(pending);
      if (found != null) return found;
      throw const ReportSubmissionException(
        'Your report may already have been submitted. Please retry to check '
        'the same submission. Your draft and uploaded photos have been kept.',
      );
    }
  }

  ReportSubmissionResult _result(dynamic response, _PendingReport pending) {
    if (response is! Map ||
        response['id'] != pending.requestId ||
        response['reportCode'] is! String ||
        (response['reportCode'] as String).isEmpty) {
      throw const FormatException('Invalid submission response');
    }
    return ReportSubmissionResult(reportCode: response['reportCode'] as String);
  }

  Future<void> _forget(
      SharedPreferences preferences, _PendingReport pending) async {
    final uid = pending.uid;
    _checkSession(uid);
    if (!await preferences.remove(_pendingKey(uid, pending.requestId))) {
      throw const ReportSubmissionException(
        'Your report was saved, but this device could not finish confirmation. '
        'Retry to recover its reference.',
      );
    }
    _checkSession(uid);
  }

  bool _sameSession(String uid) =>
      !AppSession.instance.isPreview &&
      _backend.isConfigured &&
      _backend.verifiedUserId == uid;

  void _checkSession(String uid) {
    if (!_sameSession(uid)) {
      throw const ReportSubmissionException(
        'Your session changed. Sign in to the original account to finish '
        'submitting. Your draft is still here.',
      );
    }
  }
}

class _PendingReport {
  const _PendingReport({
    required this.uid,
    required this.requestId,
    required this.draft,
    required this.payload,
  });
  final String uid;
  final String requestId;
  final String draft;
  final Map<String, dynamic> payload;

  String encode() => jsonEncode({
        'uid': uid,
        'requestId': requestId,
        'draft': draft,
        'payload': payload,
      });

  static _PendingReport decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final uid = map['uid'] as String;
      final requestId = map['requestId'] as String;
      final draft = map['draft'] as String;
      final payload = Map<String, dynamic>.from(map['payload'] as Map);
      final paths = List<String>.from(payload['p_media_paths'] as List);
      final fingerprint = jsonDecode(draft) as Map<String, dynamic>;
      if (!Uuid.isValidUUID(fromString: requestId) ||
          payload['p_request_id'] != requestId ||
          paths.isEmpty ||
          paths.length > ReportSubmissionService.maxImages ||
          paths.toSet().length != paths.length ||
          !paths.every((path) => isReportStoragePath(path, owner: uid)) ||
          fingerprint['title'] != payload['p_title'] ||
          fingerprint['description'] != payload['p_description'] ||
          fingerprint['category'] != payload['p_category'] ||
          fingerprint['latitude'] != payload['p_latitude'] ||
          fingerprint['longitude'] != payload['p_longitude'] ||
          (fingerprint['photos'] as List).length != paths.length) {
        throw const FormatException('Invalid pending report');
      }
      ReportSubmissionService._validateDraft(
        payload['p_title'] as String,
        payload['p_description'] as String,
        payload['p_category'] as String,
        LatLng(
          (payload['p_latitude'] as num).toDouble(),
          (payload['p_longitude'] as num).toDouble(),
        ),
        paths.length,
      );
      return _PendingReport(
        uid: uid,
        requestId: requestId,
        draft: draft,
        payload: payload,
      );
    } catch (_) {
      // Never discard an unreadable record and allocate a potentially duplicate ID.
      throw const ReportSubmissionException(
        'An earlier submission on this device could not be read. '
        'Keep this device data and contact CivicConnect support before retrying.',
      );
    }
  }
}
