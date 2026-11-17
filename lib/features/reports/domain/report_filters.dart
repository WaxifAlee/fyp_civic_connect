import 'package:flutter/material.dart';
import '../../../models/report.dart';

enum ReportStatus {
  pending('Submitted', Icons.schedule_outlined),
  inProgress('In progress', Icons.engineering_outlined),
  resolved('Resolved', Icons.check_circle_outline),
  rejected('Closed', Icons.cancel_outlined),
  unknown('Awaiting update', Icons.info_outline);

  const ReportStatus(this.label, this.icon);
  final String label;
  final IconData icon;

  static ReportStatus parse(String? value) => switch (value
          ?.trim()
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')) {
        'solved' || 'done' || 'resolved' || 'completed' => resolved,
        'in progress' || 'inprogress' || 'processing' => inProgress,
        'pending' || 'submitted' || 'open' => pending,
        'rejected' || 'closed' => rejected,
        _ => unknown,
      };
}

const reportCategories = [
  (
    value: 'Municipal Corportaion',
    label: 'Municipal services',
    icon: Icons.delete_outline
  ),
  (
    value: 'Police Department',
    label: 'Public safety',
    icon: Icons.shield_outlined
  ),
  (
    value: 'Fire & Emergency Services',
    label: 'Fire & emergency',
    icon: Icons.local_fire_department_outlined
  ),
  (
    value: 'Electricity & Gas Department',
    label: 'Electricity & gas',
    icon: Icons.lightbulb_outline
  ),
  (
    value: 'Public Works Department (PWD)',
    label: 'Roads & infrastructure',
    icon: Icons.add_road_outlined
  ),
];

String categoryLabel(String? value) =>
    reportCategories.where((c) => c.value == value).firstOrNull?.label ??
    value ??
    'Community issue';
IconData categoryIcon(String? value) =>
    reportCategories.where((c) => c.value == value).firstOrNull?.icon ??
    Icons.flag_outlined;

enum ReportSort { newest, oldest, mostSupported }

class ReportFilter {
  const ReportFilter(
      {this.query = '',
      this.category,
      this.status,
      this.sort = ReportSort.newest});
  final String query;
  final String? category;
  final ReportStatus? status;
  final ReportSort sort;

  List<Report> apply(List<Report> reports) {
    final search = query.trim().toLowerCase();
    final result = reports.where((report) {
      final text = [
        report.title,
        report.description,
        report.reportCode,
        report.location,
        categoryLabel(report.category)
      ].whereType<String>().join(' ').toLowerCase();
      return (search.isEmpty || text.contains(search)) &&
          (category == null || report.category == category) &&
          (status == null || ReportStatus.parse(report.status) == status);
    }).toList();
    result.sort((a, b) {
      if (sort == ReportSort.mostSupported) {
        final votes = (b.upvotes ?? 0).compareTo(a.upvotes ?? 0);
        if (votes != 0) return votes;
      }
      final dates =
          (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970));
      return sort == ReportSort.oldest ? -dates : dates;
    });
    return result;
  }
}
