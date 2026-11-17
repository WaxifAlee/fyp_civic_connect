import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shares one exit decision between system Back, modal dismissal and navigation.
class LeaveGuard extends StatefulWidget {
  const LeaveGuard(
      {super.key,
      required this.dirty,
      required this.title,
      required this.message,
      required this.builder,
      this.busy = false,
      this.unresolved = false,
      this.unresolvedMessage =
          'Retry the pending action before closing so its result can be confirmed.'});
  final bool dirty, busy, unresolved;
  final String title, message, unresolvedMessage;
  final Widget Function(BuildContext, Future<bool> Function()) builder;

  @override
  State<LeaveGuard> createState() => _LeaveGuardState();
}

class _LeaveGuardState extends State<LeaveGuard> {
  bool _asking = false;

  Future<bool> _confirmLeave() async {
    if (_asking) return false;
    if (widget.busy) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content:
              const Text('Please wait for the current action to finish.')));
      return false;
    }
    if (widget.unresolved) {
      _asking = true;
      try {
        await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Confirm your last change'),
                    content: Text(widget.unresolvedMessage),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Return to report'))
                    ]));
      } finally {
        _asking = false;
      }
      return false;
    }
    if (!widget.dirty) return true;
    _asking = true;
    try {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(widget.title),
                  content: Text(widget.message),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep editing')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Discard draft')),
                  ]));
      return mounted && discard == true && !widget.busy && !widget.unresolved;
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !widget.dirty && !widget.busy && !widget.unresolved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _asking) return;
        if (await _confirmLeave() && context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            await SystemNavigator.pop();
          }
        }
      },
      child: widget.builder(context, _confirmLeave));
}
