import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/app_session.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../../reports/domain/report_filters.dart';
import '../../reports/widgets/report_card.dart';
import '../application/authority_controller.dart';
import '../data/authority_service.dart';
import '../domain/authority_models.dart';
import '../widgets/authority_report_dialog.dart';

class AuthorityWorkspaceScreen extends StatefulWidget {
  const AuthorityWorkspaceScreen({super.key, this.service});
  final AuthorityService? service;
  @override
  State<AuthorityWorkspaceScreen> createState() =>
      _AuthorityWorkspaceScreenState();
}

class _AuthorityWorkspaceScreenState extends State<AuthorityWorkspaceScreen> {
  late final AuthorityController _controller;
  final _search = TextEditingController();
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _controller = AuthorityController(service: widget.service)..load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    _controller.reset();
  }

  void _review(AuthorityReport item) => showAuthorityReport(context,
      id: item.report.id!,
      service: _controller.service,
      onSaved: () => _controller.load());
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      Material(
          color: theme.colorScheme.surface,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: LayoutBuilder(
                  builder: (context, c) => Row(children: [
                        BrandMark(compact: c.maxWidth < 720),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Text(
                                MediaQuery.textScalerOf(context).scale(1) > 1.5
                                    ? 'Authority'
                                    : 'Authority workspace',
                                style: theme.textTheme.titleMedium)),
                        if (c.maxWidth >= 720)
                          TextButton.icon(
                              onPressed: () => Navigator.pushReplacementNamed(
                                  context, '/dashboard'),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Citizen view'))
                        else
                          IconButton(
                              tooltip: 'Open citizen view',
                              onPressed: () => Navigator.pushReplacementNamed(
                                  context, '/dashboard'),
                              icon: const Icon(Icons.home_outlined)),
                        IconButton(
                            tooltip: 'Change appearance',
                            onPressed: () => AppSession.instance.setThemeMode(
                                theme.brightness == Brightness.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark),
                            icon: Icon(theme.brightness == Brightness.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined)),
                      ])))),
      const Divider(height: 1),
      if (AppSession.instance.isPreview)
        Material(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: LayoutBuilder(builder: (context, c) {
                  const label = Row(children: [
                    Icon(Icons.visibility_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Authority demo · Sample data'))
                  ]);
                  final exit = TextButton(
                      onPressed: () {
                        AppSession.instance.leavePreview();
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/', (_) => false);
                      },
                      child: const Text('Exit demo'));
                  if (c.maxWidth < 600 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          label,
                          Align(alignment: Alignment.centerRight, child: exit)
                        ]);
                  }
                  return Row(children: [const Expanded(child: label), exit]);
                }))),
      Expanded(
          child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final access = _controller.access;
                return CivicPage(
                    maxWidth: 1320,
                    title: 'Service report queue',
                    description: access == null
                        ? 'Review local issues and keep citizens informed.'
                        : '${access.label} · ${access.isAdmin ? 'Administrator' : 'Department team'}',
                    actions: [
                      OutlinedButton.icon(
                          onPressed: _controller.loading
                              ? null
                              : () => _controller.load(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh queue'))
                    ],
                    children: [
                      if (_controller.denied)
                        AppPanel(
                            child: EmptyState(
                                icon: Icons.admin_panel_settings_outlined,
                                title: 'Service-team access required',
                                message: _controller.error ??
                                    'This account is not assigned to a service team. Ask an administrator to grant access to the correct department.',
                                actionLabel: 'Open citizen dashboard',
                                onAction: () => Navigator.pushReplacementNamed(
                                    context, '/dashboard')))
                      else if (access == null && _controller.error != null)
                        _failure()
                      else if (access == null)
                        const LoadingState()
                      else ...[
                        _metrics(),
                        AppPanel(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionHeading(
                                      title: 'Reports to review',
                                      subtitle:
                                          'Open a report to inspect photos and publish a progress update.'),
                                  const SizedBox(height: 20),
                                  _filters(),
                                  const SizedBox(height: 20),
                                  if (_controller.loading)
                                    const SizedBox(
                                        height: 260,
                                        child: Center(child: LoadingState()))
                                  else if (_controller.error != null)
                                    _failure()
                                  else if (_controller.page?.reports.isEmpty ??
                                      true)
                                    EmptyState(
                                        icon: Icons.inbox_outlined,
                                        title: (_controller.page
                                                        ?.counts['total'] ??
                                                    0) ==
                                                0
                                            ? 'No reports in this workspace'
                                            : 'No reports match these filters',
                                        message: (_controller.page
                                                        ?.counts['total'] ??
                                                    0) ==
                                                0
                                            ? 'New citizen reports for your departments will appear here. Refresh to check for new submissions.'
                                            : 'Try another reference, search term, department or status.',
                                        actionLabel: 'Clear filters',
                                        onAction: _reset)
                                  else ...[
                                    _queue(),
                                    const SizedBox(height: 20),
                                    _pagination()
                                  ],
                                ])),
                        Text(
                            'Counts cover ${access.isAdmin ? 'all departments' : access.label}. Queue results follow your filters.${_controller.lastLoaded == null ? '' : ' Last refreshed ${DateFormat('d MMM, HH:mm').format(_controller.lastLoaded!)}.'}',
                            style: theme.textTheme.bodySmall),
                      ],
                    ]);
              })),
    ])));
  }

  Widget _failure() => EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'The queue could not be loaded',
      message: _controller.error ?? 'Check your connection and try again.',
      actionLabel: 'Try again',
      onAction: () => _controller.load());
  Widget _metrics() => LayoutBuilder(builder: (context, c) {
        final theme = Theme.of(context);
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = c.maxWidth >= 1000 && scale < 1.5
            ? 5
            : c.maxWidth >= 600 && scale < 1.5
                ? 3
                : c.maxWidth >= 320 && scale < 1.7
                    ? 2
                    : 1;
        final width = (c.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final status in <String?>[null, ...authorityStatuses])
            SizedBox(
                width: width,
                child: Material(
                    color: _controller.status == status
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: _controller.status == status
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                        key: ValueKey('metric-${status ?? 'total'}'),
                        onTap: () => _controller.setStatus(status),
                        child: Semantics(
                            button: true,
                            selected: _controller.status == status,
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(
                                            status == null
                                                ? Icons.assignment_outlined
                                                : ReportStatus.parse(status)
                                                    .icon,
                                            size: 20,
                                            color: theme.colorScheme.primary),
                                        const Spacer(),
                                        if (_controller.status == status)
                                          Icon(Icons.check,
                                              size: 18,
                                              color: theme.colorScheme.primary)
                                      ]),
                                      const SizedBox(height: 14),
                                      Text(
                                          _controller.loading ||
                                                  _controller.error != null
                                              ? '—'
                                              : '${_controller.page?.counts[status ?? 'total'] ?? 0}',
                                          style:
                                              theme.textTheme.headlineMedium),
                                      const SizedBox(height: 4),
                                      Text(
                                          status == null
                                              ? 'All reports'
                                              : ReportStatus.parse(status)
                                                  .label,
                                          style: theme.textTheme.labelLarge)
                                    ]))))))
        ]);
      });
  Widget _filters() => LayoutBuilder(builder: (context, c) {
        final search = TextField(
            controller: _search,
            maxLength: 120,
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350),
                  () => _controller.load(query: value));
            },
            onSubmitted: (value) {
              _debounce?.cancel();
              _controller.load(query: value);
            },
            decoration: InputDecoration(
                labelText: 'Search reports',
                hintText: 'Reference, title or description',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _debounce?.cancel();
                          _search.clear();
                          _controller.load(query: '');
                        },
                        icon: const Icon(Icons.close))));
        final category = DropdownButtonFormField<String>(
            key: ValueKey('category-${_controller.category}'),
            initialValue: _controller.category ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All departments')),
              for (final item in reportCategories)
                DropdownMenuItem(
                    value: item.value,
                    child: Text(item.label, overflow: TextOverflow.ellipsis))
            ],
            onChanged: (value) =>
                _controller.setCategory(value == '' ? null : value));
        final sort = DropdownButtonFormField<String>(
            key: ValueKey('sort-${_controller.sort}'),
            initialValue: _controller.sort,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Queue order'),
            items: const [
              DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
              DropdownMenuItem(value: 'newest', child: Text('Newest first')),
              DropdownMenuItem(value: 'support', child: Text('Most supported'))
            ],
            onChanged: (value) => _controller.setSort(value ?? 'oldest'));
        final stacked =
            c.maxWidth < 850 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final fields = [
          search,
          if (_controller.access!.isAdmin) category,
          sort
        ];
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked) ...[
                for (final field in fields)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14), child: field)
              ] else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(flex: i == 0 ? 3 : 2, child: fields[i])
                  ]
                ]),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        _controller.status == null
                            ? 'All statuses'
                            : 'Status: ${ReportStatus.parse(_controller.status).label}',
                        style: Theme.of(context).textTheme.labelLarge),
                    TextButton.icon(
                        onPressed: _reset,
                        icon:
                            const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: const Text('Clear filters'))
                  ]),
            ]);
      });
  Widget _queue() => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 950 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.4;
        final theme = Theme.of(context);
        Widget text(String value) =>
            Text(value, style: theme.textTheme.bodySmall);
        Widget row(List<Widget> children) =>
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 4, child: children[0]),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: children[1]),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: children[2]),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: children[3]),
              const SizedBox(width: 12),
              SizedBox(width: 76, child: children[4])
            ]);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) ...[
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: row([
                      text('REPORT / REFERENCE'),
                      text('DEPARTMENT'),
                      text('STATUS'),
                      text('SUBMITTED'),
                      text('ACTION')
                    ])),
                const Divider(height: 1)
              ],
              for (final item in _controller.page!.reports) ...[
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: wide
                        ? row([
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.report.title ?? 'Community report',
                                      style: theme.textTheme.labelLarge,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  text(
                                      '${item.report.reportCode ?? 'Reference unavailable'} · ${item.report.upvotes ?? 0} supporters')
                                ]),
                            text(categoryLabel(item.report.category)),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(
                                    status: ReportStatus.parse(
                                        item.report.status))),
                            text(item.report.date == null
                                ? 'Date unavailable'
                                : DateFormat('d MMM yyyy')
                                    .format(item.report.date!.toLocal())),
                            TextButton(
                                key: ValueKey('review-${item.report.id}'),
                                onPressed: () => _review(item),
                                child: const Text('Review')),
                          ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      StatusBadge(
                                          status: ReportStatus.parse(
                                              item.report.status)),
                                      text(item.report.reportCode ?? 'Report')
                                    ]),
                                const SizedBox(height: 12),
                                Text(item.report.title ?? 'Community report',
                                    style: theme.textTheme.titleMedium),
                                const SizedBox(height: 8),
                                text(categoryLabel(item.report.category)),
                                const SizedBox(height: 8),
                                Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      text(
                                          '${reportAge(item.report.date)} · ${item.report.upvotes ?? 0} supporters'),
                                      OutlinedButton.icon(
                                          key: ValueKey(
                                              'review-${item.report.id}'),
                                          onPressed: () => _review(item),
                                          icon: const Icon(Icons.arrow_forward,
                                              size: 18),
                                          label: const Text('Review report'))
                                    ]),
                              ])),
                const Divider(height: 1),
              ],
            ]);
      });
  Widget _pagination() {
    final total = _controller.page!.total;
    final start = _controller.pageIndex * 20 + 1;
    final end = (start + _controller.page!.reports.length - 1).clamp(0, total);
    return Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
              liveRegion: true,
              child: Text('$start–$end of $total matching reports',
                  style: Theme.of(context).textTheme.bodySmall)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _controller.pageIndex == 0 || _controller.loading
                    ? null
                    : () =>
                        _controller.load(pageIndex: _controller.pageIndex - 1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous')),
            OutlinedButton.icon(
                onPressed: end >= total || _controller.loading
                    ? null
                    : () =>
                        _controller.load(pageIndex: _controller.pageIndex + 1),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'))
          ])
        ]);
  }
}
