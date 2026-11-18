import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../../../core/widgets/leave_guard.dart';
import '../../../core/widgets/refresh_shortcuts.dart';
import '../../../core/widgets/form_validation.dart';
import '../../reports/application/report_comments_controller.dart';
import '../../reports/domain/report_filters.dart';
import '../../reports/widgets/report_card.dart';
import '../../reports/widgets/report_progress_panel.dart';
import '../../reports/widgets/report_comments_panel.dart';
import '../data/authority_service.dart';
import '../domain/authority_models.dart';

Future<void> showAuthorityReport(BuildContext context,
        {required String id,
        required AuthorityService service,
        required VoidCallback onSaved}) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            AuthorityReportDialog(id: id, service: service, onSaved: onSaved));

class AuthorityReportDialog extends StatefulWidget {
  const AuthorityReportDialog(
      {super.key,
      required this.id,
      required this.service,
      required this.onSaved});
  final String id;
  final AuthorityService service;
  final VoidCallback onSaved;
  @override
  State<AuthorityReportDialog> createState() => _AuthorityReportDialogState();
}

class _AuthorityReportDialogState extends State<AuthorityReportDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  late final ReportCommentsController _comments;
  AuthorityDetail? _detail;
  String? _status;
  String? _error;
  String? _success;
  String? _requestId;
  bool _loading = true;
  bool _busy = false;
  bool _mustReload = false;
  bool _uncertain = false;
  bool _acknowledged = false;
  String? _session;
  @override
  void initState() {
    super.initState();
    _session = widget.service.sessionId;
    _comments = ReportCommentsController(reportId: widget.id)
      ..load()
      ..addListener(_changed);
    _reload();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_busy || _loading || _comments.busy || _uncertain) return;
    await Future.wait([
      _reload(),
      if (_comments.canRefresh) _comments.load(),
    ]);
  }

  @override
  void dispose() {
    _note.dispose();
    _comments.removeListener(_changed);
    _comments.dispose();
    super.dispose();
  }

  Future<void> _reload({bool afterPublish = false}) async {
    final refreshQueue = _uncertain;
    final preserveDraft =
        _detail != null && !_uncertain && !_acknowledged && !afterPublish;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.service.detail(widget.id);
      if (!mounted) return;
      if (_session != widget.service.sessionId) {
        setState(() {
          _detail = null;
          _error = 'Your session changed. Close this report and sign in again.';
        });
        return;
      }
      final draftStatus = _status;
      setState(() {
        _detail = detail;
        final currentStatus = detail.item.report.status!;
        _status = preserveDraft &&
                authorityTransitions(currentStatus).contains(draftStatus)
            ? draftStatus
            : currentStatus;
        _mustReload = false;
        _uncertain = false;
        _acknowledged = false;
        _requestId = null;
        if (!preserveDraft) _note.clear();
        if (preserveDraft && _note.text.isNotEmpty) {
          _success = _status == draftStatus
              ? 'Latest report loaded. Your unpublished draft is ready to review.'
              : 'Latest report loaded. Your note is preserved; select a status for the updated report.';
        } else if (refreshQueue) {
          _success =
              'Latest history loaded and queue refreshed. Review the history before writing another update.';
        }
      });
      if (refreshQueue) widget.onSaved();
    } on AuthorityException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.forbidden || _session != widget.service.sessionId) {
            _detail = null;
          }
          _mustReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    if (_session != widget.service.sessionId) {
      setState(() {
        _detail = null;
        _mustReload = true;
        _error = 'Your session changed. Close this report and sign in again.';
      });
      return;
    }
    if (_busy ||
        _loading ||
        _mustReload ||
        !validateAndReveal(_form.currentState) ||
        _detail == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    _requestId ??= const Uuid().v4();
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.service.publish(
          id: widget.id,
          version: _detail!.item.version,
          status: _status!,
          note: _note.text,
          requestId: _requestId!);
      if (!mounted) return;
      if (_session != widget.service.sessionId) {
        setState(() {
          _detail = null;
          _mustReload = true;
          _error = 'Your session changed. Close this report and sign in again.';
        });
        return;
      }
      _acknowledged = true;
      widget.onSaved();
      await _reload(afterPublish: true);
      if (mounted && !_mustReload) {
        setState(() => _success = widget.service.isPreview
            ? 'Demo update saved in this session. Nothing was sent to hosted services.'
            : 'Update published. Citizens can now see it in the report history.');
      }
    } on AuthorityException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _mustReload = e.conflict || e.forbidden;
          _uncertain = e.uncertain;
          if (e.forbidden) _detail = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable =
        !_busy && (!_loading || _detail != null) && !_mustReload && !_uncertain;
    final item = _detail?.item;
    final guardedDialog = LeaveGuard(
        dirty: _comments.draft.isNotEmpty ||
            (!_acknowledged &&
                (_note.text.isNotEmpty ||
                    (item != null && _status != item.report.status))),
        busy: _busy || _comments.busy,
        unresolved: (_uncertain && _session == widget.service.sessionId) ||
            (!_comments.blocked &&
                (_comments.uncertain || _comments.pendingRemoval != null)),
        title: 'Discard report changes?',
        message:
            'Your unpublished service note or comment will be discarded. Published updates will remain on the report.',
        builder: (context, _) => Dialog(
            insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 40,
                vertical: 24),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 820,
                    maxHeight: MediaQuery.sizeOf(context).height - 48),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                          child: Row(children: [
                            Expanded(
                                child: Text('Service report',
                                    style: theme.textTheme.titleLarge)),
                            IconButton(
                                tooltip: 'Close service report',
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.maybePop(context),
                                icon: const Icon(Icons.close))
                          ])),
                      const Divider(height: 1),
                      Expanded(
                          child: RefreshIndicator.adaptive(
                              onRefresh: _refresh,
                              semanticsLabel:
                                  'Refresh service report and comments',
                              child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_loading)
                                          const LinearProgressIndicator(
                                              semanticsLabel:
                                                  'Loading latest report'),
                                        if (_error != null) ...[
                                          InlineNotice(
                                              message: _error!, isError: true),
                                          const SizedBox(height: 16),
                                          if (_mustReload || item == null)
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: OutlinedButton.icon(
                                                    onPressed: _busy || _loading
                                                        ? null
                                                        : _reload,
                                                    icon: const Icon(
                                                        Icons.refresh),
                                                    label: const Text(
                                                        'Reload latest report')))
                                        ],
                                        if (_success != null) ...[
                                          InlineNotice(message: _success!),
                                          const SizedBox(height: 16)
                                        ],
                                        if (item != null) ...[
                                          Wrap(
                                              spacing: 12,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                    item.report.reportCode ??
                                                        'Report',
                                                    style: theme
                                                        .textTheme.labelLarge),
                                                StatusBadge(
                                                    status: ReportStatus.parse(
                                                        item.report.status)),
                                                Text(
                                                    categoryLabel(
                                                        item.report.category),
                                                    style: theme
                                                        .textTheme.bodySmall)
                                              ]),
                                          const SizedBox(height: 16),
                                          SelectableText(
                                              item.report.title ??
                                                  'Community report',
                                              style: theme
                                                  .textTheme.headlineSmall),
                                          const SizedBox(height: 12),
                                          Text(
                                              'Submitted ${item.report.date == null ? 'date unavailable' : DateFormat('d MMM yyyy, HH:mm').format(item.report.date!.toLocal())} · ${item.report.upvotes ?? 0} supporters',
                                              style: theme.textTheme.bodySmall),
                                          const SizedBox(height: 20),
                                          SelectableText(
                                              item.report.description ??
                                                  'No description supplied.',
                                              style: theme.textTheme.bodyLarge),
                                          const SizedBox(height: 16),
                                          SelectableText(
                                              'Location: ${item.report.location ?? 'Unavailable'}',
                                              style: theme.textTheme.bodySmall),
                                          if (item.report.location
                                                  ?.isNotEmpty ??
                                              false)
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: TextButton.icon(
                                                  icon: const Icon(
                                                      Icons.open_in_new,
                                                      size: 18),
                                                  label: const Text(
                                                      'Open location in Maps'),
                                                  onPressed: () async {
                                                    final uri = Uri.https(
                                                        'www.google.com',
                                                        '/maps/search/', {
                                                      'api': '1',
                                                      'query':
                                                          item.report.location!
                                                    });
                                                    try {
                                                      if (await launchUrl(uri,
                                                          mode: LaunchMode
                                                              .externalApplication)) {
                                                        return;
                                                      }
                                                    } catch (_) {
                                                      /* Show actionable feedback below. */
                                                    }
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                              const SnackBar(
                                                                  content: Text(
                                                                      'Maps could not be opened. Copy the coordinates to your map app.')));
                                                    }
                                                  },
                                                )),
                                          if (item.report.mediaRefrence
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            SizedBox(
                                                height: 180,
                                                child: ListView.separated(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    itemCount: item.report
                                                        .mediaRefrence.length,
                                                    separatorBuilder: (_, __) =>
                                                        const SizedBox(
                                                            width: 12),
                                                    itemBuilder: (context, index) => ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12),
                                                        child: Image.network(item.report.mediaRefrence[index],
                                                            width: 240,
                                                            height: 180,
                                                            fit: BoxFit.cover,
                                                            semanticLabel:
                                                                'Report photo ${index + 1}',
                                                            errorBuilder: (_, __, ___) =>
                                                                Container(width: 240, color: theme.colorScheme.surfaceContainerHighest, child: const Center(child: Text('Photo unavailable')))))))
                                          ],
                                          const SizedBox(height: 24),
                                          const Divider(),
                                          const SizedBox(height: 20),
                                          Text('Publish a service update',
                                              style:
                                                  theme.textTheme.titleLarge),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Status changes and notes are visible to citizens. Include what happened and the next step.',
                                              style: theme.textTheme.bodySmall),
                                          const SizedBox(height: 20),
                                          Form(
                                              key: _form,
                                              child: Column(children: [
                                                DropdownButtonFormField<String>(
                                                    key: ValueKey(
                                                        'status-${item.version}-$_loading'),
                                                    initialValue: _status,
                                                    isExpanded: true,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Report status',
                                                            prefixIcon: Icon(Icons
                                                                .flag_outlined)),
                                                    items: [
                                                      for (final status
                                                          in authorityTransitions(
                                                              item.report
                                                                  .status!))
                                                        DropdownMenuItem(
                                                            value: status,
                                                            child: Text(
                                                                '${ReportStatus.parse(status).label}${status == item.report.status ? ' · current' : ''}'))
                                                    ],
                                                    onChanged: editable
                                                        ? (value) =>
                                                            setState(() {
                                                              _status = value;
                                                              _requestId = null;
                                                            })
                                                        : null),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                    key: const ValueKey(
                                                        'progress-note'),
                                                    controller: _note,
                                                    enabled: editable,
                                                    maxLines: 4,
                                                    minLines: 3,
                                                    maxLength: 1000,
                                                    decoration: const InputDecoration(
                                                        labelText:
                                                            'Public progress note',
                                                        hintText:
                                                            'For example: A crew inspected the site. Repairs are scheduled for Thursday.',
                                                        alignLabelWithHint:
                                                            true),
                                                    onChanged: (_) => setState(
                                                        () =>
                                                            _requestId = null),
                                                    validator: (value) => value ==
                                                                null ||
                                                            value
                                                                    .trim()
                                                                    .length <
                                                                10
                                                        ? 'Write at least 10 characters.'
                                                        : value.trim().length >
                                                                1000
                                                            ? 'Keep this note within 1,000 characters.'
                                                            : null),
                                              ])),
                                          const SizedBox(height: 24),
                                          Text('Published history',
                                              style:
                                                  theme.textTheme.titleLarge),
                                          const SizedBox(height: 16),
                                          ProgressHistory(
                                              history: _detail!.history),
                                          const SizedBox(height: 24),
                                          ReportCommentsPanel(
                                              key: ValueKey(
                                                  'discussion-${widget.id}'),
                                              controller: _comments,
                                              reportId: widget.id),
                                        ],
                                      ])))),
                      const Divider(height: 1),
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => Navigator.maybePop(context),
                                    child: const Text('Close')),
                                FilledButton.icon(
                                    onPressed: item == null ||
                                            _busy ||
                                            _loading ||
                                            _mustReload
                                        ? null
                                        : _publish,
                                    icon: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(Icons.publish_outlined,
                                            size: 20),
                                    label: Text(_uncertain
                                        ? 'Retry same update'
                                        : 'Publish update'))
                              ])),
                    ]))));
    return RefreshShortcuts(onRefresh: _refresh, child: guardedDialog);
  }
}
