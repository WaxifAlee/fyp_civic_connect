import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/app_session.dart';
import '../../../services/report_service.dart';
import '../domain/report_comment.dart';
import 'preview_comments.dart';
export '../domain/report_comment.dart';

class ReportCommentsService {
  ReportCommentsService({ReportBackend? backend})
      : _backend = backend ?? ReportBackend();
  final ReportBackend _backend;
  bool get isPreview => AppSession.instance.isPreview;
  String? get sessionId =>
      isPreview ? 'comments-preview' : _backend.verifiedUserId;

  Future<dynamic> _call(String name, Map<String, dynamic> params,
      {bool mutation = false}) async {
    final uid = sessionId;
    if (uid == null || isPreview || !_backend.isConfigured) {
      throw const CommentsException(
          'Sign in with a verified account to join this discussion.',
          forbidden: true);
    }
    try {
      final raw = await _backend.rpc(name, params);
      if (sessionId != uid) {
        throw const CommentsException(
            'Your session changed. Close this report and sign in again.',
            forbidden: true);
      }
      return raw;
    } on CommentsException {
      rethrow;
    } catch (e) {
      if (sessionId != uid) {
        throw const CommentsException(
            'Your session changed. Close this report and sign in again.',
            forbidden: true);
      }
      if (e is PostgrestException) {
        if (e.code == '42501') {
          throw const CommentsException(
              'This discussion is unavailable. The report may have been removed, or your session expired.',
              forbidden: true);
        }
        if (e.code == '23514' || e.code == '22P02') {
          throw const CommentsException(
              'Write a comment between 1 and 1,000 characters, then try again.');
        }
        if (e.code == 'PT409') {
          throw const CommentsException(
              'This comment was removed. Write a new comment to continue.');
        }
      }
      throw CommentsException(
          mutation
              ? 'The change could not be confirmed. Retry the same action to check it safely.'
              : 'Comments could not be loaded. Check your connection and try again.',
          uncertain: mutation);
    }
  }

  Future<CommentsPage> list(String reportId, {ReportComment? before}) async {
    if (isPreview) {
      final items = PreviewComments.items(reportId);
      final start =
          before == null ? 0 : items.indexWhere((c) => c.id == before.id) + 1;
      return CommentsPage(
          comments: List.unmodifiable(items.skip(start).take(20)),
          hasMore: items.length > start + 20);
    }
    final raw = await _call('list_report_comments', {
      'p_report_id': reportId,
      'p_limit': 20,
      'p_before_at': before?.timestamp,
      'p_before_id': before?.id,
    });
    try {
      if (raw is! Map ||
          raw['comments'] is! List ||
          raw['hasMore'] is! bool ||
          (raw['comments'] as List).length > 20) {
        throw const FormatException();
      }
      final items = (raw['comments'] as List)
          .map(
              (r) => ReportComment.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (items.any((c) => c.reportId != reportId) ||
          (raw['hasMore'] == true && items.isEmpty)) {
        throw const FormatException();
      }
      return CommentsPage(
          comments: List.unmodifiable(items), hasMore: raw['hasMore']);
    } catch (_) {
      throw const CommentsException(
          'Comments returned incomplete data. Refresh to try again.');
    }
  }

  Future<ReportComment> add(
      String reportId, String body, String requestId) async {
    final canonical = body.trim();
    if (canonical.isEmpty || canonical.runes.length > 1000) {
      throw const CommentsException(
          'Write a comment between 1 and 1,000 characters.');
    }
    if (isPreview) return PreviewComments.add(reportId, canonical, requestId);
    final raw = await _call(
        'add_report_comment',
        {
          'p_report_id': reportId,
          'p_body': canonical,
          'p_request_id': requestId,
        },
        mutation: true);
    try {
      final item = ReportComment.fromMap(Map<String, dynamic>.from(raw as Map));
      if (item.id != requestId ||
          item.reportId != reportId ||
          item.body != canonical ||
          !item.isMine) {
        throw const FormatException();
      }
      return item;
    } catch (_) {
      throw const CommentsException(
          'The posted comment could not be confirmed. Retry the same comment to check it safely.',
          uncertain: true);
    }
  }

  Future<void> remove(String reportId, String commentId) async {
    if (isPreview) {
      PreviewComments.remove(reportId, commentId);
      return;
    }
    final raw = await _call(
        'delete_report_comment',
        {
          'p_report_id': reportId,
          'p_comment_id': commentId,
        },
        mutation: true);
    if (raw is! Map || raw['id'] != commentId || raw['deleted'] != true) {
      throw const CommentsException(
          'Removal could not be confirmed. Retry removal to check it safely.',
          uncertain: true);
    }
  }
}
