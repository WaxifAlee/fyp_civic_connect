import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/services/supabase_client.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
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
    // This guard precedes even accessing Firebase or Supabase singletons.
    if (AppSession.instance.isPreview) {
      throw const ReportSubmissionException(
        'Preview reports stay on this device. Return to the form to preview it.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ReportSubmissionException(
        'Sign in before submitting a report. Your draft is still here.',
      );
    }
    final prefix = categoryPrefixes[category];
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
    if (prefix == null) {
      throw const ReportSubmissionException('Choose a department.');
    }
    final locationError = FatehJangArea.validate(
      location.latitude,
      location.longitude,
    );
    if (locationError != null) throw ReportSubmissionException(locationError);
    if (images.isEmpty || images.length > maxImages) {
      throw const ReportSubmissionException('Add between 1 and 3 photos.');
    }
    if (!SupabaseService.isConfigured) {
      throw const ReportSubmissionException(
        'Photo uploads are not set up yet. Your draft is safe here. '
        'Ask the CivicConnect administrator to enable uploads, then try again.',
      );
    }

    final paths = <String>[];
    SupabaseClient? client;
    try {
      onProgress?.call(0.05, 'Checking your photos…');
      // Validate every photo before beginning any remote upload.
      final photos = <ReportPhoto>[];
      for (final image in images) {
        photos.add(await readPhoto(image));
      }
      await SupabaseService.initialize();
      client = Supabase.instance.client;
      final storage = client.storage.from('reports-images');
      final imageUrls = <String>[];
      for (var i = 0; i < photos.length; i++) {
        _checkSession(user.uid);
        final photo = photos[i];
        final path = 'public/${const Uuid().v4()}.${photo.extension}';
        // Record before the call so a lost upload response can also be cleaned.
        paths.add(path);
        onProgress?.call(
          0.1 + 0.65 * i / photos.length,
          'Uploading photo ${i + 1} of ${photos.length}…',
        );
        final result = await storage.uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.contentType),
        );
        if (result.isEmpty) {
          throw const ReportSubmissionException(
            'A photo could not be uploaded. Your draft is kept; please try again.',
          );
        }
        imageUrls.add(storage.getPublicUrl(path));
      }
      _checkSession(user.uid);
      onProgress?.call(0.85, 'Saving your report…');
      final firestore = FirebaseFirestore.instance;
      final reportRef = firestore.collection('reports').doc();
      final counterRef = firestore.collection('report_counters').doc(prefix);
      final citizen =
          globalCitizenUser?.uid == user.uid ? globalCitizenUser : null;
      // Allocate the human-readable code and create the report atomically.
      // A failed write never presents a timestamp fallback as a report code.
      final code = await firestore.runTransaction<String>((transaction) async {
        _checkSession(user.uid);
        final counter = await transaction.get(counterRef);
        final current = counter.data()?['counter'];
        final next = (current is num ? current.toInt() : 0) + 1;
        final code = '$prefix${next.toString().padLeft(5, '0')}';
        transaction.set(counterRef, {'counter': next}, SetOptions(merge: true));
        transaction.set(reportRef, {
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'location': '${location.latitude}, ${location.longitude}',
          'images': imageUrls,
          'reporterId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'avatar': citizen?.displayPicture ?? user.photoURL ?? '',
          'reporterName': citizen?.fullName ?? user.displayName ?? 'Citizen',
          'reportCode': code,
          'upvotes': 0,
          'upvotedBy': <String>[],
        });
        return code;
      });
      return ReportSubmissionResult(reportCode: code);
    } catch (error) {
      if (paths.isNotEmpty && client != null) {
        onProgress?.call(0.85, 'Removing unfinished uploads…');
        try {
          await client.storage.from('reports-images').remove(paths);
        } catch (_) {
          // Storage permissions/network can prevent best-effort cleanup.
          // Never mask the original error or erase the citizen's draft.
        }
      }
      if (error is ReportSubmissionException) rethrow;
      if (error is FirebaseException && error.code == 'permission-denied') {
        throw const ReportSubmissionException(
          'Your account could not save this report. Sign in again or contact '
          'CivicConnect support. Your draft is still here.',
        );
      }
      if (error is StorageException) {
        throw const ReportSubmissionException(
          'The photos could not be uploaded. Check your connection and try '
          'again. If this continues, contact CivicConnect support. '
          'Your draft is still here.',
        );
      }
      throw const ReportSubmissionException(
        'The report could not be saved. Check your connection and try again. '
        'Your details and photos are still here.',
      );
    }
  }

  void _checkSession(String uid) {
    if (AppSession.instance.isPreview ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const ReportSubmissionException(
        'Your session changed. Sign in again before submitting. '
        'Your draft is still here.',
      );
    }
  }
}
