import '../../../models/report.dart';
import '../../reports/data/preview_reports.dart';
import '../../reports/data/preview_progress.dart';
import '../../reports/domain/report_filters.dart';
import '../../reports/domain/report_progress.dart';
import '../domain/authority_models.dart';

abstract final class AuthorityPreview {
  static final _versions = <String, int>{};
  static final _requests = <String, (String, int, String, String)>{};
  static AuthorityReport _item(Report report) => AuthorityReport(
      report: report,
      version: _versions[report.id] ?? 0,
      updatedAt: PreviewProgress.history(report.id!).firstOrNull?.createdAt ??
          report.date ??
          DateTime(1970));
  static AuthorityPage queue(
      {required String query,
      String? status,
      String? category,
      required String sort,
      required int page}) {
    final all = PreviewReports.reports;
    final counts = {
      'total': all.length,
      for (final s in authorityStatuses)
        s: all
            .where((r) =>
                r.status == s ||
                (s == 'inprogress' && r.status == 'in progress'))
            .length
    };
    final filtered = ReportFilter(
            query: query,
            status: status == null ? null : ReportStatus.parse(status),
            category: category,
            sort: switch (sort) {
              'newest' => ReportSort.newest,
              'support' => ReportSort.mostSupported,
              _ => ReportSort.oldest
            })
        .apply(all);
    return AuthorityPage(
        reports: filtered.skip(page * 20).take(20).map(_item).toList(),
        total: filtered.length,
        counts: counts);
  }

  static AuthorityDetail detail(String id) {
    final report = PreviewReports.reports.where((r) => r.id == id).firstOrNull;
    if (report == null) {
      throw const AuthorityException('This report is no longer available.');
    }
    // The existing demo includes a legacy status alias.
    final canonical = report.status == 'in progress'
        ? Report.fromMap({...report.toMap(), 'status': 'inprogress'})
        : report;
    return AuthorityDetail(
        item: _item(canonical), history: PreviewProgress.history(id));
  }

  static void publish(
      {required String id,
      required int version,
      required String status,
      required String note,
      required String requestId}) {
    final payload = (id, version, status, note.trim());
    if (_requests.containsKey(requestId)) {
      if (_requests[requestId] != payload) {
        throw const AuthorityException('This update request cannot be reused.');
      }
      return;
    }
    final current = detail(id).item;
    if (current.version != version) {
      throw const AuthorityException(
          'This report changed. Reload it before publishing.',
          conflict: true);
    }
    if (note.trim().length < 10 ||
        note.trim().length > 1000 ||
        !authorityTransitions(current.report.status!).contains(status)) {
      throw const AuthorityException(
          'Check the status and write a progress note of 10–1,000 characters.');
    }
    final updated =
        Report.fromMap({...current.report.toMap(), 'status': status});
    final index = PreviewReports.reports.indexWhere((r) => r.id == id);
    PreviewReports.reports[index] = updated;
    _versions[id] = version + 1;
    _requests[requestId] = payload;
    PreviewProgress.add(
        id,
        ReportProgress(
            id: requestId,
            fromStatus: current.report.status!,
            toStatus: status,
            note: note.trim(),
            createdAt: DateTime.now(),
            version: version + 1));
  }
}
