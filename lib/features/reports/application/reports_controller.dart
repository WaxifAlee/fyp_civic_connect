import 'package:flutter/foundation.dart';

import '../../../app/app_session.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';
import '../data/preview_reports.dart';

class ReportsController extends ChangeNotifier {
  ReportsController({
    this.mine = false,
    ReportService? service,
    String? Function()? userId,
  })  : _service = service ?? ReportService(),
        _userId = userId;
  final bool mine;
  final ReportService _service;
  final String? Function()? _userId;
  List<Report> reports = [];
  bool loading = true;
  String? error;
  bool _disposed = false;
  final Set<String> busyReports = {};
  String? get currentUserId => _userId != null
      ? _userId()
      : AppSession.instance.isPreview
          ? PreviewReports.citizenId
          : _serviceUserId;

  String? get _serviceUserId => ReportBackend().verifiedUserId;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    final uid = currentUserId;
    try {
      final items = AppSession.instance.isPreview
          ? PreviewReports.reports
              .where((r) => !mine || r.reportedBy == PreviewReports.citizenId)
              .toList()
          : mine
              ? await _service.fetchReportsByCurrentUser()
              : await _service.fetchAllReports();
      if (_disposed || currentUserId != uid) return;
      reports = items
        ..sort(
          (a, b) =>
              (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)),
        );
    } catch (_) {
      if (_disposed) return;
      error =
          'We couldn’t load your reports. Check your connection and try again.';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> toggleUpvote(Report report) async {
    final id = report.id;
    final uid = currentUserId;
    if (id == null || uid == null || busyReports.contains(id)) return false;
    busyReports.add(id);
    _notify();
    try {
      final committed = AppSession.instance.isPreview
          ? null
          : await _service.toggleUpvote(id);
      if (_disposed || currentUserId != uid) return false;
      if (committed != null) {
        report.upvotedBy = committed.voters.contains(uid) ? [uid] : [];
        report.upvotes = committed.count;
        return true;
      }
      final voters = List<String>.from(report.upvotedBy ?? []);
      final voted = voters.contains(uid);
      voted ? voters.remove(uid) : voters.add(uid);
      report.upvotedBy = voters;
      report.upvotes = ((report.upvotes ?? 0) + (voted ? -1 : 1)).clamp(
        0,
        1 << 31,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      busyReports.remove(id);
      _notify();
    }
  }

  Future<bool> delete(Report report) async {
    final id = report.id;
    if (id == null ||
        busyReports.contains(id) ||
        report.reportedBy != currentUserId) {
      return false;
    }
    final uid = currentUserId;
    busyReports.add(id);
    _notify();
    try {
      if (AppSession.instance.isPreview) {
        PreviewReports.reports.removeWhere((item) => item.id == id);
      } else {
        await _service.deleteReport(id, report.mediaRefrence);
      }
      if (_disposed || currentUserId != uid) return false;
      reports.removeWhere((item) => item.id == id);
      return true;
    } catch (_) {
      return false;
    } finally {
      busyReports.remove(id);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
