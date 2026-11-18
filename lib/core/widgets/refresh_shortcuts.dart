import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps refresh available to desktop users without adding header controls.
class RefreshShortcuts extends StatefulWidget {
  const RefreshShortcuts(
      {super.key, required this.onRefresh, required this.child});

  final Future<void> Function()? onRefresh;
  final Widget child;

  @override
  State<RefreshShortcuts> createState() => _RefreshShortcutsState();
}

class _RefreshShortcutsState extends State<RefreshShortcuts> {
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  bool _handleKey(KeyEvent event) {
    final refresh = widget.onRefresh;
    if (refresh == null ||
        !(_route?.isCurrent ?? true) ||
        event is! KeyDownEvent) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    final matched = const [
      SingleActivator(LogicalKeyboardKey.f5),
      SingleActivator(LogicalKeyboardKey.keyR, control: true),
      SingleActivator(LogicalKeyboardKey.keyR, meta: true),
    ].any((shortcut) => shortcut.accepts(event, keyboard));
    if (!matched) return false;
    refresh();
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
