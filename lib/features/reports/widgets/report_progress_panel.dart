import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/report_progress_service.dart';
import '../domain/report_progress.dart';
import '../domain/report_filters.dart';
import 'status_badge.dart';

class ProgressHistory extends StatelessWidget {
  const ProgressHistory({super.key, required this.history});
  final List<ReportProgress> history;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (history.isEmpty) {
      return Text(
          'No service-team updates yet. Published progress will appear here.',
          style: theme.textTheme.bodySmall);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final item in history)
        Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(ReportStatus.parse(item.toStatus).icon,
                      size: 20, color: theme.colorScheme.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(
                              status: ReportStatus.parse(item.toStatus)),
                          Text(
                              DateFormat('d MMM yyyy, HH:mm')
                                  .format(item.createdAt.toLocal()),
                              style: theme.textTheme.bodySmall)
                        ]),
                    const SizedBox(height: 8),
                    SelectableText(item.note,
                        style: theme.textTheme.bodyMedium),
                  ])),
            ])),
    ]);
  }
}

class ReportProgressPanel extends StatefulWidget {
  const ReportProgressPanel(
      {super.key, required this.reportId, this.service, this.onLatestStatus});
  final String reportId;
  final ReportProgressService? service;
  final ValueChanged<String>? onLatestStatus;
  @override
  State<ReportProgressPanel> createState() => _ReportProgressPanelState();
}

class _ReportProgressPanelState extends State<ReportProgressPanel> {
  late Future<List<ReportProgress>> _history;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _history = (widget.service ?? ReportProgressService())
        .history(widget.reportId)
        .then((history) {
      if (mounted && history.isNotEmpty) {
        widget.onLatestStatus?.call(history.first.toStatus);
      }
      return history;
    });
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Service updates', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        FutureBuilder<List<ReportProgress>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(
                    semanticsLabel: 'Loading service updates');
              }
              if (snapshot.hasError) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Service updates could not be loaded.'),
                      TextButton.icon(
                          onPressed: () => setState(_load),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry updates'))
                    ]);
              }
              return ProgressHistory(history: snapshot.data ?? []);
            }),
      ]);
}
