import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// The small SDK boundary shared by report reads and submissions.
/// Constructing it never accesses the SDK, so preview works before initialization.
class ReportBackend {
  bool get isConfigured => SupabaseService.isConfigured;
  SupabaseClient get _client => SupabaseService.client;

  String? get verifiedUserId {
    if (AppSession.instance.isPreview || !isConfigured) return null;
    final user = _client.auth.currentUser;
    return user?.emailConfirmedAt != null ? user?.id : null;
  }

  Future<dynamic> rpc(String name, Map<String, dynamic> params) =>
      _client.rpc(name, params: params);

  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    await _client.storage.from('reports-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
  }

  Future<void> remove(List<String> paths) async {
    await _client.storage.from('reports-images').remove(paths);
  }

  String publicUrl(String bucket, String path) =>
      _client.storage.from(bucket).getPublicUrl(path);
}

/// Storage references are relative UID/file paths, never arbitrary URLs.
bool isReportStoragePath(String path, {String? owner}) {
  final parts = path.split('/');
  return parts.length == 2 &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(parts.first) &&
      (owner == null || parts.first == owner) &&
      RegExp(r'^[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$').hasMatch(parts.last);
}

/// Supabase RPCs own report authorization, counters and support transactions.
class ReportService {
  ReportService({ReportBackend? backend})
      : _backend = backend ?? ReportBackend();
  final ReportBackend _backend;

  String _requireSession([String? expected]) {
    if (AppSession.instance.isPreview || !_backend.isConfigured) {
      throw StateError('Sign in to access reports.');
    }
    final uid = _backend.verifiedUserId;
    if (uid == null || (expected != null && uid != expected)) {
      throw StateError('Sign in with a verified account to access reports.');
    }
    return uid;
  }

  Future<List<Report>> fetchAllReports({
    String? category,
    String? status,
    bool sortByPopularity = false,
  }) async {
    final reports = await _fetch(mine: false);
    final filtered = reports
        .where(
          (report) =>
              (category == null ||
                  category.isEmpty ||
                  report.category == category) &&
              (status == null || status.isEmpty || report.status == status),
        )
        .toList();
    filtered.sort((a, b) {
      if (sortByPopularity) {
        final support = (b.upvotes ?? 0).compareTo(a.upvotes ?? 0);
        if (support != 0) return support;
      }
      final date = (b.date ?? DateTime(1970)).compareTo(
        a.date ?? DateTime(1970),
      );
      return date != 0 ? date : (b.id ?? '').compareTo(a.id ?? '');
    });
    return filtered;
  }

  Future<List<Report>> fetchReportsByCurrentUser() => _fetch(mine: true);

  Future<List<Report>> _fetch({required bool mine}) async {
    final uid = _requireSession();
    final reports = <Report>[];
    // Each request is bounded, while dashboard statistics retain the full feed.
    for (var offset = 0;; offset += 200) {
      _requireSession(uid);
      final page = await _backend.rpc('list_reports', {
        'p_mine': mine,
        'p_limit': 200,
        'p_offset': offset,
      });
      _requireSession(uid);
      if (page is! List || page.length > 200) {
        throw StateError('Invalid report response.');
      }
      for (final item in page) {
        final map = Map<String, dynamic>.from(item as Map);
        map['images'] = (map['images'] as List? ?? [])
            .whereType<String>()
            .where((path) => isReportStoragePath(path))
            .map((path) => _backend.publicUrl('reports-images', path))
            .toList();
        final avatar = map['avatar'];
        map['avatar'] = avatar is String && isReportStoragePath(avatar)
            ? _backend.publicUrl('profile-pictures', avatar)
            : '';
        // Even a malformed server response must not expose other supporters.
        map['upvotedBy'] = (map['upvotedBy'] as List? ?? []).contains(uid)
            ? [uid]
            : <String>[];
        final report = Report.fromMap(map);
        if (!mine || report.reportedBy == uid) reports.add(report);
      }
      if (page.length < 200) {
        if (mine) await _flushCleanup(uid);
        _requireSession(uid);
        return reports;
      }
    }
  }

  Future<void> deleteReport(String reportId, List<String> imagePaths) async {
    final uid = _requireSession();
    final response = await _backend.rpc('delete_report', {
      'p_report_id': reportId,
    });
    _requireSession(uid);
    // The caller's image URLs are presentation data. Only the server's paths
    // authorize cleanup, after the row has been deleted successfully.
    if (response is! List) throw StateError('Invalid delete response.');
    await _cleanup(reportId, response, uid);
  }

  Future<void> _flushCleanup(String uid) async {
    try {
      _requireSession(uid);
      final response = await _backend.rpc('list_report_cleanup', {});
      _requireSession(uid);
      if (response is! List) return;
      for (final item in response) {
        _requireSession(uid);
        if (item is Map &&
            item['reportId'] is String &&
            item['paths'] is List) {
          await _cleanup(
              item['reportId'] as String, item['paths'] as List, uid);
          _requireSession(uid);
        }
      }
    } catch (_) {
      // Listing own reports remains useful while cleanup is temporarily offline.
      // The private server manifest survives for the next own-report fetch.
    }
  }

  Future<void> _cleanup(
      String reportId, List<dynamic> response, String uid) async {
    try {
      _requireSession(uid);
      final paths = response
          .whereType<String>()
          .where((path) => isReportStoragePath(path, owner: uid))
          .toSet()
          .toList();
      if (paths.isNotEmpty) {
        await _backend.remove(paths);
        _requireSession(uid);
      }
      _requireSession(uid);
      // The server clears the manifest only when ALL referenced objects are
      // absent. A lost remove/complete response can safely be retried later.
      await _backend.rpc('complete_report_cleanup', {'p_report_id': reportId});
      _requireSession(uid);
    } catch (_) {
      // Database deletion already succeeded; storage cleanup is retryable.
      debugPrint('Report removed; photo cleanup will be retried.');
    }
  }

  Future<ReportVote> toggleUpvote(String reportId) async {
    final uid = _requireSession();
    final response = await _backend.rpc('toggle_report_support', {
      'p_report_id': reportId,
    });
    _requireSession(uid);
    if (response is! Map ||
        response['count'] is! num ||
        response['voters'] is! List) {
      throw StateError('Invalid support response.');
    }
    return ReportVote(
      count: (response['count'] as num).toInt().clamp(0, 1 << 31),
      voters: (response['voters'] as List).contains(uid) ? [uid] : [],
    );
  }
}
