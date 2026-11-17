import '../app/app_session.dart';
import '../features/reports/data/preview_progress.dart';
import '../features/reports/domain/report_progress.dart';
import 'report_service.dart';

class ReportProgressService {
  ReportProgressService({ReportBackend? backend})
      : _backend = backend ?? ReportBackend();
  final ReportBackend _backend;
  Future<List<ReportProgress>> history(String id) async {
    if (AppSession.instance.isPreview) return PreviewProgress.history(id);
    final uid = _backend.verifiedUserId;
    if (uid == null) throw StateError('Verified session required');
    final raw = await _backend.rpc('get_report_progress', {'p_report_id': id});
    if (uid != _backend.verifiedUserId) throw StateError('Session changed');
    return (raw as List)
        .map((h) => ReportProgress.fromMap(Map<String, dynamic>.from(h as Map)))
        .toList();
  }
}
