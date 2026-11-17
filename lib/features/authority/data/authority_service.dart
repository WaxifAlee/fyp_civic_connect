import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/app_session.dart';
import '../../../services/report_service.dart';
import '../../reports/domain/report_progress.dart';
import '../domain/authority_models.dart';
import 'authority_preview.dart';

class AuthorityService {
  AuthorityService({ReportBackend? backend})
      : _backend = backend ?? ReportBackend();
  final ReportBackend _backend;
  String? get sessionId => AppSession.instance.isPreview
      ? 'authority-demo'
      : _backend.verifiedUserId;
  bool get isPreview => AppSession.instance.isPreview;
  Future<dynamic> _call(String name, Map<String, dynamic> params,
      {bool mutation = false}) async {
    final uid = sessionId;
    if (isPreview || !_backend.isConfigured || uid == null) {
      throw const AuthorityException(
          'Sign in with a verified service-team account.',
          forbidden: true);
    }
    try {
      final result = await _backend.rpc(name, params);
      if (sessionId != uid) {
        throw const AuthorityException('Your session changed. Sign in again.',
            forbidden: true);
      }
      return result;
    } on AuthorityException {
      rethrow;
    } on PostgrestException catch (e) {
      if (sessionId != uid) {
        throw const AuthorityException('Your session changed. Sign in again.',
            forbidden: true);
      }
      if (e.code == '42501') {
        throw const AuthorityException(
            'Your account does not have access to this department. Ask an administrator to check your access.',
            forbidden: true);
      }
      if (e.code == 'PT409') {
        throw const AuthorityException(
            'Another team member updated this report. Reload the latest version before publishing.',
            conflict: true);
      }
      if (e.code == '23514') {
        throw const AuthorityException(
            'Check the selected status and progress note, then try again.');
      }
      throw AuthorityException(
          mutation
              ? 'The update could not be confirmed. Retry the same update or reload the report to check its history.'
              : 'The workspace could not be loaded. Check your connection and try again.',
          uncertain: mutation);
    } catch (_) {
      if (sessionId != uid) {
        throw const AuthorityException('Your session changed. Sign in again.',
            forbidden: true);
      }
      throw AuthorityException(
          mutation
              ? 'The update could not be confirmed. Retry the same update or reload the report to check its history.'
              : 'The workspace could not be loaded. Check your connection and try again.',
          uncertain: mutation);
    }
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      throw const AuthorityException(
          'The workspace returned incomplete data. Refresh to try again.');
    }
  }

  Future<AuthorityAccess?> access() async {
    if (isPreview) return const AuthorityAccess(role: 'admin');
    final result = await _call('get_authority_access', {});
    return result == null
        ? null
        : _parse(() =>
            AuthorityAccess.fromMap(Map<String, dynamic>.from(result as Map)));
  }

  Map<String, dynamic> _report(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    map['images'] = (map['images'] as List? ?? [])
        .whereType<String>()
        .where(isReportStoragePath)
        .map((path) => _backend.publicUrl('reports-images', path))
        .toList();
    map['avatar'] = '';
    map['upvotedBy'] = <String>[];
    return map;
  }

  Future<AuthorityPage> queue(
      {String query = '',
      String? status,
      String? category,
      String sort = 'oldest',
      int page = 0}) async {
    if (isPreview) {
      return AuthorityPreview.queue(
          query: query,
          status: status,
          category: category,
          sort: sort,
          page: page);
    }
    final result = await _call('authority_dashboard', {
      'p_query': query.trim(),
      'p_status': status,
      'p_category': category,
      'p_sort': sort,
      'p_limit': 20,
      'p_offset': page * 20
    });
    return _parse(() {
      final map = Map<String, dynamic>.from(result as Map);
      final counts = Map<String, dynamic>.from(map['counts'] as Map);
      if (map['total'] is! int ||
          map['total'] < 0 ||
          (map['reports'] as List).length > 20 ||
          ['total', ...authorityStatuses]
              .any((s) => counts[s] is! int || counts[s] < 0)) {
        throw const FormatException();
      }
      return AuthorityPage(
          reports: (map['reports'] as List)
              .map((r) => AuthorityReport.fromMap(_report(r)))
              .toList(),
          total: map['total'],
          counts: counts.cast<String, int>());
    });
  }

  Future<AuthorityDetail> detail(String id) async {
    if (isPreview) return AuthorityPreview.detail(id);
    final raw = await _call('authority_report_detail', {'p_report_id': id});
    return _parse(() => AuthorityDetail(
        item: AuthorityReport.fromMap(_report(raw['report'])),
        history: (raw['history'] as List)
            .map((h) =>
                ReportProgress.fromMap(Map<String, dynamic>.from(h as Map)))
            .toList()));
  }

  Future<void> publish(
      {required String id,
      required int version,
      required String status,
      required String note,
      required String requestId}) async {
    if (isPreview) {
      AuthorityPreview.publish(
          id: id,
          version: version,
          status: status,
          note: note,
          requestId: requestId);
      return;
    }
    final receipt = await _call(
        'authority_update_report',
        {
          'p_report_id': id,
          'p_expected_version': version,
          'p_status': status,
          'p_note': note.trim(),
          'p_request_id': requestId
        },
        mutation: true);
    if (receipt is! Map ||
        receipt['id'] != id ||
        receipt['status'] != status ||
        receipt['version'] != version + 1 ||
        DateTime.tryParse(receipt['updatedAt']?.toString() ?? '') == null) {
      throw const AuthorityException(
          'The update could not be confirmed. Retry the same update or reload the report to check its history.',
          uncertain: true);
    }
  }
}
