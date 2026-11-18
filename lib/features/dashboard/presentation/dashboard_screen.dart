import 'package:flutter/material.dart';
import '../../../app/app_session.dart';
import '../../../app/app_shell.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../../../services/user_service.dart';
import '../../reports/application/reports_controller.dart';
import '../../reports/domain/report_filters.dart';
import '../../reports/widgets/report_card.dart';
import '../widgets/community_banner.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _controller = ReportsController(mine: true);
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = AppSession.instance.isPreview
        ? 'Ayesha'
        : (globalCitizenUser?.fullName?.trim().split(' ').firstOrNull ??
            'neighbour');
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return AppShell(
        onRefresh: _controller.load,
        currentIndex: 0,
        child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => CivicPage(
                    onRefresh: _controller.load,
                    refreshing: _controller.loading && _controller.hasLoaded,
                    title: '$greeting, $name.',
                    description:
                        'Here’s what’s happening in your corner of the community.',
                    children: [
                      const CommunityBanner(),
                      if (_controller.error != null)
                        InlineNotice(
                            message: _controller.error!, isError: true),
                      _metrics(context),
                      LayoutBuilder(builder: (context, constraints) {
                        final recent = _recentReports(context);
                        final guide = _guide(context);
                        if (constraints.maxWidth < 850 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                recent,
                                const SizedBox(height: 24),
                                guide
                              ]);
                        }
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: recent),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: guide)
                            ]);
                      }),
                      AppPanel(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.diversity_3_outlined,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Your voice has a place here.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Explore local issues and support your neighbours. Together, we can make everyday places better.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                          onPressed: () =>
                                              Navigator.pushReplacementNamed(
                                                  context, '/explore'),
                                          label: const Text(
                                              'Explore community issues'),
                                          icon: const Icon(Icons.arrow_forward,
                                              size: 18),
                                          iconAlignment: IconAlignment.end)
                                    ]))
                              ])),
                    ])));
  }

  Widget _metrics(BuildContext context) {
    final reports = _controller.reports;
    final metrics = [
      (
        label: 'Total reports',
        count: reports.length,
        icon: Icons.assignment_outlined,
        note: 'Your contributions',
        status: null
      ),
      for (final status in [
        ReportStatus.pending,
        ReportStatus.inProgress,
        ReportStatus.resolved,
        ReportStatus.rejected
      ])
        (
          label: status.label,
          count: reports
              .where((r) => ReportStatus.parse(r.status) == status)
              .length,
          icon: status.icon,
          note: switch (status) {
            ReportStatus.pending => 'Awaiting review',
            ReportStatus.inProgress => 'Being worked on',
            ReportStatus.resolved => 'A difference made',
            _ => 'Review the outcome',
          },
          status: status
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final theme = Theme.of(context);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = c.maxWidth >= 1000 && scale < 1.5
          ? 5
          : c.maxWidth >= 700 && scale < 1.5
              ? 3
              : c.maxWidth >= 300 && scale < 1.7
                  ? 2
                  : 1;
      final width = (c.maxWidth - (columns - 1) * 16) / columns;
      final available = _controller.hasLoaded;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (final metric in metrics)
          SizedBox(
              width: width,
              child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey(
                        'personal-metric-${metric.status?.name ?? 'total'}'),
                    onTap: !available
                        ? null
                        : () => Navigator.pushReplacementNamed(
                            context, '/my_reports',
                            arguments: metric.status),
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(metric.icon,
                                    size: 22, color: theme.colorScheme.primary),
                                const Spacer(),
                                Icon(Icons.arrow_forward,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant)
                              ]),
                              const SizedBox(height: 16),
                              Text(available ? '${metric.count}' : '—',
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(fontSize: 34)),
                              const SizedBox(height: 4),
                              Text(metric.label,
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(metric.note,
                                  style: theme.textTheme.bodySmall),
                            ])),
                  ))),
      ]);
    });
  }

  Widget _recentReports(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeading(
            title: 'Your recent reports',
            subtitle: 'Small actions. Real community impact.',
            action: TextButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/my_reports'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                iconAlignment: IconAlignment.end,
                label: const Text('View all'))),
        const SizedBox(height: 18),
        if (_controller.loading && !_controller.hasLoaded)
          const LoadingState()
        else if (_controller.error != null && !_controller.hasLoaded)
          AppPanel(
              child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Reports unavailable',
                  message:
                      'Please refresh to try loading your recent reports again.',
                  actionLabel: 'Try again',
                  onAction: _controller.load))
        else if (_controller.reports.isEmpty)
          AppPanel(
              child: EmptyState(
                  title: 'Make your first contribution',
                  message:
                      'A clear report helps the right people understand what needs attention.',
                  actionLabel: 'Report an issue',
                  onAction: () =>
                      Navigator.pushReplacementNamed(context, '/report_issue')))
        else
          for (final report in _controller.reports.take(3))
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReportCard(report: report, compact: true)),
      ]);

  Widget _guide(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.tips_and_updates_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Make your report count',
                style: theme.textTheme.titleMedium))
      ]),
      const SizedBox(height: 22),
      for (final item in [
        (
          Icons.photo_camera_outlined,
          'Show the issue clearly',
          'Add a clear, well-lit photo from a safe distance.'
        ),
        (
          Icons.location_on_outlined,
          'Pin the right spot',
          'An accurate location makes an issue easier to find.'
        ),
        (
          Icons.notes_outlined,
          'Keep it specific',
          'Describe what happened and how it affects your area.'
        )
      ])
        Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(item.$1,
                  color: theme.colorScheme.onSurfaceVariant, size: 21),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.$2, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 5),
                    Text(item.$3, style: theme.textTheme.bodySmall)
                  ]))
            ])),
      const Divider(),
      const SizedBox(height: 12),
      TextButton.icon(
          onPressed: () => showCommunityGuide(context),
          icon: const Icon(Icons.help_outline, size: 18),
          label: const Text('How CivicConnect works'))
    ]));
  }
}
