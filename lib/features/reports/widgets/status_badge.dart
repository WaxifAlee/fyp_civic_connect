import 'package:flutter/material.dart';
import '../domain/report_filters.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final ReportStatus status;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attention =
        status == ReportStatus.pending || status == ReportStatus.inProgress;
    final closed = status == ReportStatus.rejected;
    final background = closed
        ? scheme.surfaceContainerHighest
        : attention
            ? scheme.secondaryContainer
            : scheme.primaryContainer;
    final foreground = closed
        ? scheme.onSurfaceVariant
        : attention
            ? scheme.onSecondaryContainer
            : scheme.onPrimaryContainer;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Flexible(
              child: Text(status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground, fontWeight: FontWeight.w600)))
        ]));
  }
}
