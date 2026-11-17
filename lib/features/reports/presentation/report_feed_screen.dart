import 'package:flutter/material.dart';
import '../../../app/app_shell.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../../../models/report.dart';
import '../application/reports_controller.dart';
import '../domain/report_filters.dart';
import '../widgets/report_card.dart';
import '../widgets/report_filters_bar.dart';

class ExploreIssuesScreen extends StatelessWidget {
  const ExploreIssuesScreen({super.key});
  @override
  Widget build(BuildContext context) => const ReportFeedScreen();
}

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key, this.initialStatus});
  final ReportStatus? initialStatus;
  @override
  Widget build(BuildContext context) =>
      ReportFeedScreen(mine: true, initialStatus: initialStatus);
}

class ReportFeedScreen extends StatefulWidget {
  const ReportFeedScreen({super.key, this.mine = false, this.initialStatus});
  final ReportStatus? initialStatus;
  final bool mine;
  @override
  State<ReportFeedScreen> createState() => _ReportFeedScreenState();
}

class _ReportFeedScreenState extends State<ReportFeedScreen> {
  late final ReportsController _controller;
  final _search = TextEditingController();
  ReportStatus? _status;
  String? _category;
  ReportSort _sort = ReportSort.newest;
  int _visibleCount = 12;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _controller = ReportsController(mine: widget.mine)..load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _search.clear();
        _status = null;
        _category = null;
        _sort = ReportSort.newest;
        _visibleCount = 12;
      });

  @override
  Widget build(BuildContext context) => AppShell(
      currentIndex: widget.mine ? 3 : 1,
      child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final filtered = ReportFilter(
                    query: _search.text,
                    status: _status,
                    category: _category,
                    sort: _sort)
                .apply(_controller.reports);
            return CivicPage(
                title: widget.mine ? 'My reports' : 'Explore your community',
                description: widget.mine
                    ? 'Every report is a step toward a better neighbourhood. Follow yours here.'
                    : 'See what’s happening nearby. Add your support to the issues that matter.',
                actions: [
                  IconButton(
                      tooltip: 'Refresh reports',
                      onPressed: _controller.loading ? null : _controller.load,
                      icon: const Icon(Icons.refresh)),
                  FilledButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(
                          context, '/report_issue'),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Report an issue'))
                ],
                children: [
                  _filters(context),
                  if (_controller.loading)
                    const LoadingState()
                  else if (_controller.error != null)
                    AppPanel(
                        child: EmptyState(
                            icon: Icons.wifi_off_outlined,
                            title: 'A little trouble connecting',
                            message: _controller.error!,
                            actionLabel: 'Try again',
                            onAction: _controller.load))
                  else if (_controller.reports.isEmpty)
                    AppPanel(
                        child: EmptyState(
                            icon: widget.mine
                                ? Icons.assignment_outlined
                                : Icons.location_city_outlined,
                            title: widget.mine
                                ? 'Your first report starts here'
                                : 'No community reports yet',
                            message: widget.mine
                                ? 'Spotted something that needs attention? Add a photo and help your community take the next step.'
                                : 'Be the first to report an issue in your neighbourhood.',
                            actionLabel: 'Report an issue',
                            onAction: () => Navigator.pushReplacementNamed(
                                context, '/report_issue')))
                  else if (filtered.isEmpty)
                    AppPanel(
                        child: EmptyState(
                            icon: Icons.search_off_outlined,
                            title: 'No matching reports',
                            message:
                                'Try another search or clear your filters to see more reports.',
                            actionLabel: 'Clear filters',
                            onAction: _reset))
                  else ...[
                    Semantics(
                        liveRegion: true,
                        child: Text(
                            '${filtered.length} ${filtered.length == 1 ? 'report' : 'reports'}${_status != null ? ' · ${_status!.label}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall)),
                    for (final report in filtered.take(_visibleCount))
                      ReportCard(
                          report: report,
                          currentUserId: _controller.currentUserId,
                          busy: _controller.busyReports.contains(report.id),
                          onSupport: () => _support(report),
                          onDelete: widget.mine ? () => _delete(report) : null),
                    if (filtered.length > _visibleCount)
                      Center(
                          child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _visibleCount += 12),
                              icon: const Icon(Icons.expand_more),
                              label: Text(
                                  'Show more (${filtered.length - _visibleCount} remaining)'))),
                  ],
                ]);
          }));

  Widget _filters(BuildContext context) => ReportFiltersBar(
        search: _search,
        category: _category,
        status: _status,
        sort: _sort,
        onSearchChanged: (_) => setState(() => _visibleCount = 12),
        onChanged: (category, status, sort) => setState(() {
          _category = category;
          _status = status;
          _sort = sort;
          _visibleCount = 12;
        }),
        onReset: _reset,
      );

  Future<void> _support(Report report) async {
    final successful = await _controller.toggleUpvote(report);
    if (!successful && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your support couldn’t be saved. Please try again.')));
    }
  }

  Future<bool> _delete(Report report) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete this report?'),
                content: Text(
                    '“${report.title ?? 'This report'}” will be permanently removed. This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep report')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError),
                      child: const Text('Delete report'))
                ]));
    if (confirmed != true || !mounted) return false;
    final successful = await _controller.delete(report);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successful
              ? 'Report deleted.'
              : 'Your report couldn’t be deleted. Please try again.')));
    }
    return successful;
  }
}
