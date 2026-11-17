import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../../../models/report.dart';
import '../domain/report_filters.dart';
import 'report_progress_panel.dart';
import 'report_comments_panel.dart';
import 'status_badge.dart';
export 'status_badge.dart';

String reportAge(DateTime? date) {
  if (date == null) return 'Date unavailable';
  final age = DateTime.now().difference(date);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  if (age.inDays < 7) return '${age.inDays}d ago';
  return DateFormat('d MMM yyyy').format(date);
}

class ReportCard extends StatelessWidget {
  const ReportCard(
      {super.key,
      required this.report,
      this.currentUserId,
      this.onSupport,
      this.onDelete,
      this.busy = false,
      this.compact = false});
  final Report report;
  final String? currentUserId;
  final Future<void> Function()? onSupport;
  final Future<bool> Function()? onDelete;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supported = report.upvotedBy?.contains(currentUserId) ?? false;
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: () => _showDetails(context),
            child: Padding(
                padding: EdgeInsets.all(compact ? 18 : 22),
                child: LayoutBuilder(builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 480 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ReportThumbnail(
                                  report: report, size: compact ? 48 : 58),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(categoryLabel(report.category),
                                        style: theme.textTheme.bodySmall),
                                    const SizedBox(height: 4),
                                    Text(report.title ?? 'Community report',
                                        maxLines: compact ? 2 : 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium)
                                  ])),
                              if (!narrow) ...[
                                const SizedBox(width: 16),
                                StatusBadge(
                                    status: ReportStatus.parse(report.status))
                              ],
                            ]),
                        if (narrow) ...[
                          const SizedBox(height: 12),
                          StatusBadge(status: ReportStatus.parse(report.status))
                        ],
                        if (!compact) ...[
                          const SizedBox(height: 14),
                          Text(
                              report.description ??
                                  'Open this report to see its details.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant))
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(report.reportCode ?? 'Report',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                color:
                                                    scheme.onSurfaceVariant)),
                                    Text('· ${reportAge(report.date)}',
                                        style: theme.textTheme.bodySmall)
                                  ]),
                              if (!compact)
                                TextButton.icon(
                                    onPressed: busy ? null : onSupport,
                                    icon: busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : Icon(
                                            supported
                                                ? Icons.arrow_circle_up
                                                : Icons
                                                    .arrow_circle_up_outlined,
                                            size: 20),
                                    label: Text(
                                        '${report.upvotes ?? 0} ${supported ? 'Supported' : 'Support'}'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: supported
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10)))
                              else
                                const Icon(Icons.arrow_forward, size: 18),
                            ]),
                      ]);
                }))));
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: FractionallySizedBox(
                heightFactor: .92,
                child: ReportDetails(
                    report: report,
                    currentUserId: currentUserId,
                    onSupport: onSupport,
                    onDelete: onDelete))));
  }
}

class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({required this.report, required this.size});
  final Report report;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
        width: size,
        height: size,
        color: scheme.primaryContainer,
        child: Icon(categoryIcon(report.category),
            size: size * .44, color: scheme.primary));
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: report.mediaRefrence.isEmpty
            ? placeholder
            : Image.network(report.mediaRefrence.first,
                width: size,
                height: size,
                fit: BoxFit.cover,
                semanticLabel: 'Photo of ${report.title ?? 'reported issue'}',
                errorBuilder: (_, __, ___) => placeholder));
  }
}

class ReportDetails extends StatefulWidget {
  const ReportDetails(
      {super.key,
      required this.report,
      this.currentUserId,
      this.onSupport,
      this.onDelete});
  final Report report;
  final String? currentUserId;
  final Future<void> Function()? onSupport;
  final Future<bool> Function()? onDelete;
  @override
  State<ReportDetails> createState() => _ReportDetailsState();
}

class _ReportDetailsState extends State<ReportDetails> {
  bool _busy = false;
  String? _latestStatus;
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final theme = Theme.of(context);
    final supported = report.upvotedBy?.contains(widget.currentUserId) ?? false;
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('Report details',
                                style: theme.textTheme.titleLarge)),
                        IconButton(
                            tooltip: 'Close report details',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))
                      ]),
                      const SizedBox(height: 16),
                      Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusBadge(
                                status: ReportStatus.parse(
                                    _latestStatus ?? report.status)),
                            Text(categoryLabel(report.category),
                                style: theme.textTheme.bodySmall)
                          ]),
                      const SizedBox(height: 20),
                      Text(report.title ?? 'Community report',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(report.reportCode ?? 'Reference unavailable',
                                style: theme.textTheme.labelLarge),
                            if (report.reportCode != null)
                              IconButton(
                                  tooltip: 'Copy report reference',
                                  icon:
                                      const Icon(Icons.copy_outlined, size: 19),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(
                                        text: report.reportCode!));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Report reference copied')));
                                    }
                                  })
                          ]),
                      Text(
                          'Reported by ${report.reporterName ?? 'a community member'} · ${reportAge(report.date)}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      Text('What’s happening',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SelectableText(
                          report.description ??
                              'No additional description was provided.',
                          style: theme.textTheme.bodyLarge),
                      if (report.mediaRefrence.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Photos', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SizedBox(
                            height: 230,
                            child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: report.mediaRefrence.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) => SizedBox(
                                    width: 280,
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                            report.mediaRefrence[index],
                                            fit: BoxFit.cover,
                                            semanticLabel:
                                                'Issue photo ${index + 1}',
                                            errorBuilder: (_, __, ___) => Container(
                                                color: theme.colorScheme
                                                    .surfaceContainerLow,
                                                child: const Center(
                                                    child: Text(
                                                        'Photo unavailable'))))))))
                      ],
                      const SizedBox(height: 24),
                      AppPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(Icons.location_on_outlined,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text('Reported location',
                                          style: theme.textTheme.titleMedium))
                                ]),
                                const SizedBox(height: 8),
                                SelectableText(
                                    report.location ?? 'Location not provided'),
                                if (report.location?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                      onPressed: () =>
                                          _openMap(report.location!),
                                      icon: const Icon(Icons.open_in_new,
                                          size: 18),
                                      label: const Text('View in Maps'))
                                ]
                              ])),
                      const SizedBox(height: 24),
                      if (report.id != null) ...[
                        ReportProgressPanel(
                            reportId: report.id!,
                            onLatestStatus: (status) {
                              if (mounted && _latestStatus != status) {
                                setState(() => _latestStatus = status);
                              }
                            }),
                        const SizedBox(height: 24),
                        ReportCommentsPanel(
                            key: ValueKey('discussion-${report.id}'),
                            reportId: report.id!),
                        const SizedBox(height: 24),
                      ],
                      if (widget.onSupport != null)
                        AsyncButton(
                            label:
                                '${report.upvotes ?? 0} supporters · ${supported ? 'Remove support' : 'Support this issue'}',
                            icon: supported
                                ? Icons.arrow_circle_up
                                : Icons.arrow_circle_up_outlined,
                            isLoading: _busy,
                            onPressed: () async {
                              setState(() => _busy = true);
                              await widget.onSupport!();
                              if (mounted) setState(() => _busy = false);
                            }),
                      if (widget.onDelete != null) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    final deleted = await widget.onDelete!();
                                    if (!context.mounted) return;
                                    if (deleted) {
                                      Navigator.pop(context);
                                    } else {
                                      setState(() => _busy = false);
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete my report'),
                            style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error))
                      ],
                    ]))));
  }

  Future<void> _openMap(String location) async {
    try {
      final opened = await launchUrl(
          Uri.https('www.google.com', '/maps/search/',
              {'api': '1', 'query': location}),
          mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Unable to open map');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Maps couldn’t open. You can copy the location above.')));
      }
    }
  }
}
