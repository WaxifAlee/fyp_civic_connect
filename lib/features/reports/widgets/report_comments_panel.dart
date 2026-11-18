import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/civic_widgets.dart';
import '../application/report_comments_controller.dart';
import '../data/report_comments_service.dart';

class ReportCommentsPanel extends StatefulWidget {
  const ReportCommentsPanel(
      {super.key, required this.reportId, this.service, this.controller});
  final String reportId;
  final ReportCommentsService? service;

  /// Owning dialogs load/dispose this controller; standalone panels own theirs.
  final ReportCommentsController? controller;
  @override
  State<ReportCommentsPanel> createState() => _ReportCommentsPanelState();
}

class _ReportCommentsPanelState extends State<ReportCommentsPanel> {
  late ReportCommentsController _controller;
  final _draft = TextEditingController();
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _controller = widget.controller ??
        ReportCommentsController(
            reportId: widget.reportId, service: widget.service);
    _draft.value = TextEditingValue(
        text: _controller.draft,
        selection: TextSelection.collapsed(offset: _controller.draft.length));
    _controller.addListener(_changed);
    if (widget.controller == null) _controller.load();
  }

  void _changed() {
    if (!mounted) return;
    if (_draft.text != _controller.draft) {
      _draft.value = TextEditingValue(
          text: _controller.draft,
          selection: TextSelection.collapsed(offset: _controller.draft.length));
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(ReportCommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportId != widget.reportId ||
        oldWidget.service != widget.service ||
        oldWidget.controller != widget.controller) {
      _controller.removeListener(_changed);
      if (oldWidget.controller == null) _controller.dispose();
      _draft.clear();
      _start();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _remove(ReportComment item) async {
    if (_controller.pendingRemoval != item.id) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Remove this comment?'),
                  content: const Text(
                      'Your comment will be removed from this report’s discussion.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep comment')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove comment'))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    await _controller.remove(item);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(),
      const SizedBox(height: 16),
      Row(children: [
        Icon(Icons.chat_bubble_outline,
            color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('Comments', style: theme.textTheme.titleLarge)),
      ]),
      const SizedBox(height: 4),
      Text(
          'Share useful details with your community. Comments are public; keep personal information private.',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 16),
      if (c.error != null) ...[
        InlineNotice(message: c.error!, isError: true),
        if (!c.blocked && !c.uncertain && c.pendingRemoval == null)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: c.canRefresh ? c.load : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry comments'))),
        const SizedBox(height: 12),
      ],
      if (c.notice != null) ...[
        Semantics(
            liveRegion: true,
            child: Text(c.notice!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary))),
        const SizedBox(height: 12),
      ],
      if (!c.blocked) ...[
        TextField(
            key: const ValueKey('comment-draft'),
            controller: _draft,
            enabled: c.canEdit,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
                labelText: 'Add a comment',
                hintText: 'What else should the community know?',
                alignLabelWithHint: true,
                counterText: '${c.draft.trim().runes.length}/1,000',
                errorText: c.draft.trim().runes.length > 1000
                    ? 'Keep your comment within 1,000 characters.'
                    : null),
            onChanged: c.updateDraft),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
                onPressed: c.canPost
                    ? () {
                        FocusScope.of(context).unfocus();
                        c.post();
                      }
                    : null,
                icon: c.busy && c.pendingRemoval == null
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined, size: 18),
                label:
                    Text(c.uncertain ? 'Retry same comment' : 'Post comment'))),
        const SizedBox(height: 20),
      ],
      if (c.loading)
        const LinearProgressIndicator(semanticsLabel: 'Loading comments'),
      if (!c.loading && c.ready && c.comments.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No comments yet', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('Start the discussion with a helpful detail.',
                  style: theme.textTheme.bodySmall),
            ])),
      if (c.comments.isNotEmpty) ...[
        Text('Latest first', style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        for (final item in c.comments) ...[
          Container(
              key: ValueKey('comment-${item.id}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(item.authorName,
                                          style: theme.textTheme.titleSmall),
                                      if (item.isMine)
                                        Text('You',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: theme
                                                        .colorScheme.primary)),
                                    ]),
                                const SizedBox(height: 4),
                                Text(
                                    DateFormat('d MMM yyyy · HH:mm')
                                        .format(item.createdAt.toLocal()),
                                    style: theme.textTheme.bodySmall),
                              ])),
                          if (item.isMine)
                            IconButton(
                                tooltip: c.pendingRemoval == item.id
                                    ? 'Retry removing your comment'
                                    : 'Remove your comment',
                                onPressed: !c.busy &&
                                        !c.loading &&
                                        !c.loadingMore &&
                                        !c.uncertain &&
                                        !c.blocked &&
                                        (c.pendingRemoval == null ||
                                            c.pendingRemoval == item.id)
                                    ? () => _remove(item)
                                    : null,
                                icon: Icon(
                                    c.pendingRemoval == item.id
                                        ? Icons.refresh
                                        : Icons.delete_outline,
                                    size: 20)),
                        ]),
                    const SizedBox(height: 12),
                    SelectableText(item.body,
                        style: theme.textTheme.bodyMedium),
                  ])),
          const SizedBox(height: 12),
        ],
      ],
      if (c.hasMore)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: c.canRefresh ? () => c.load(older: true) : null,
                icon: c.loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more),
                label: const Text('Load older comments'))),
    ]);
  }
}
