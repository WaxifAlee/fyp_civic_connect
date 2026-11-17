import '../../../models/report.dart';
import '../../reports/domain/report_filters.dart';
import '../../reports/domain/report_progress.dart';

const authorityStatuses = ['pending', 'inprogress', 'resolved', 'rejected'];
List<String> authorityTransitions(String status) => switch (status) {
      'pending' => ['pending', 'inprogress', 'rejected'],
      'inprogress' => ['inprogress', 'resolved', 'rejected'],
      'resolved' => ['resolved', 'inprogress'],
      'rejected' => ['rejected', 'inprogress'],
      _ => [],
    };

class AuthorityAccess {
  const AuthorityAccess({required this.role, this.department});
  final String role;
  final String? department;
  bool get isAdmin => role == 'admin';
  String get label => isAdmin ? 'All departments' : categoryLabel(department);
  factory AuthorityAccess.fromMap(Map<String, dynamic> map) {
    final role = map['role'];
    final department = map['department'];
    if (!((role == 'admin' && department == null) ||
        (role == 'department' &&
            reportCategories.any((c) => c.value == department)))) {
      throw const FormatException('Invalid authority access');
    }
    return AuthorityAccess(
        role: role as String, department: department as String?);
  }
}

class AuthorityReport {
  const AuthorityReport(
      {required this.report, required this.version, required this.updatedAt});
  final Report report;
  final int version;
  final DateTime updatedAt;
  factory AuthorityReport.fromMap(Map<String, dynamic> map) {
    final date = DateTime.tryParse(map['updatedAt']?.toString() ?? '');
    if (map['id'] is! String ||
        map['version'] is! int ||
        map['version'] < 0 ||
        date == null ||
        !authorityStatuses.contains(map['status'])) {
      throw const FormatException('Invalid authority report');
    }
    return AuthorityReport(
        report: Report.fromMap(map), version: map['version'], updatedAt: date);
  }
}

class AuthorityPage {
  const AuthorityPage(
      {required this.reports, required this.total, required this.counts});
  final List<AuthorityReport> reports;
  final int total;
  final Map<String, int> counts;
}

class AuthorityDetail {
  const AuthorityDetail({required this.item, required this.history});
  final AuthorityReport item;
  final List<ReportProgress> history;
}

class AuthorityException implements Exception {
  const AuthorityException(this.message,
      {this.conflict = false, this.forbidden = false, this.uncertain = false});
  final String message;
  final bool conflict;
  final bool forbidden;
  final bool uncertain;
  @override
  String toString() => message;
}
