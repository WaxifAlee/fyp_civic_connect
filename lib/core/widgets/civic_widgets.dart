import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false, this.inverse = false});
  final bool compact;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = inverse ? Colors.white : colors.primary;
    return Semantics(
        label: 'CivicConnect',
        child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: inverse
                      ? Colors.white.withValues(alpha: .14)
                      : colors.primary,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.holiday_village_outlined,
                  color: inverse ? Colors.white : colors.onPrimary, size: 27)),
          if (!compact) ...[
            const SizedBox(width: 10),
            Text('civic',
                style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: foreground)),
            Text('connect',
                style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 23,
                    fontWeight: FontWeight.w400,
                    color: foreground))
          ],
        ])));
  }
}

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppTheme.normal,
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 10 * (1 - value)), child: child)));
  }
}

class CivicPage extends StatelessWidget {
  const CivicPage(
      {super.key,
      required this.title,
      this.description,
      this.actions = const [],
      required this.children,
      this.onRefresh,
      this.refreshing = false,
      this.maxWidth = 1160});
  final String title;
  final String? description;
  final List<Widget> actions;
  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  final bool refreshing;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final scroll = SingleChildScrollView(
            key: PageStorageKey(title),
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
                compact ? 20 : 36, compact ? 24 : 32, compact ? 20 : 36, 40),
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Entrance(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          if (refreshing) ...[
                            const LinearProgressIndicator(
                                semanticsLabel: 'Refreshing'),
                            const SizedBox(height: 16),
                          ],
                          LayoutBuilder(builder: (context, c) {
                            final heading = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                      header: true,
                                      child: Text(title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium)),
                                  if (description != null) ...[
                                    const SizedBox(height: 8),
                                    Text(description!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant))
                                  ]
                                ]);
                            if (c.maxWidth < 650 ||
                                MediaQuery.textScalerOf(context).scale(1) >
                                    1.3) {
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    heading,
                                    if (actions.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: actions)
                                    ]
                                  ]);
                            }
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: heading),
                                  if (actions.isNotEmpty) ...[
                                    const SizedBox(width: 20),
                                    Wrap(spacing: 8, children: actions)
                                  ]
                                ]);
                          }),
                          const SizedBox(height: 28),
                          for (var i = 0; i < children.length; i++) ...[
                            children[i],
                            if (i != children.length - 1)
                              const SizedBox(height: 24)
                          ],
                        ])))));
        return onRefresh == null
            ? scroll
            : RefreshIndicator.adaptive(
                onRefresh: onRefresh!,
                semanticsLabel: 'Refresh $title',
                child: scroll);
      });
}

class AppPanel extends StatelessWidget {
  const AppPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: padding, child: child));
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
      {super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                  header: true,
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
              ]
            ]),
            if (action != null) action!
          ]);
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      this.icon = Icons.inbox_outlined,
      required this.title,
      required this.message,
      this.actionLabel,
      this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle),
                    child: Icon(icon,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(onPressed: onAction, child: Text(actionLabel!))
                ]
              ]))));
}

class AsyncButton extends StatelessWidget {
  const AsyncButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.isLoading = false,
      this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            if (isLoading)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (icon != null)
              Icon(icon, size: 20),
            Text(label)
          ]));
}

class InlineNotice extends StatelessWidget {
  const InlineNotice(
      {super.key,
      required this.message,
      this.isError = false,
      this.icon = Icons.info_outline});
  final String message;
  final bool isError;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: true,
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color:
                    isError ? colors.errorContainer : colors.primaryContainer,
                borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(isError ? Icons.error_outline : icon,
                  size: 20,
                  color: isError
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(message,
                      style: TextStyle(
                          color: isError
                              ? colors.onErrorContainer
                              : colors.onPrimaryContainer,
                          height: 1.5)))
            ])));
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Loading reports…'});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      label: label,
      child: Column(children: [
        const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                  height: 96,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16)))),
        Text(label, style: Theme.of(context).textTheme.bodySmall)
      ]));
}
