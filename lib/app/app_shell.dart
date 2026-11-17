import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/widgets/civic_widgets.dart';
import '../services/user_service.dart';
import 'app_session.dart';

const _destinations = [
  (
    label: 'Overview',
    short: 'Home',
    icon: Icons.space_dashboard_outlined,
    selected: Icons.space_dashboard_rounded,
    route: '/dashboard'
  ),
  (
    label: 'Explore issues',
    short: 'Explore',
    icon: Icons.explore_outlined,
    selected: Icons.explore,
    route: '/explore'
  ),
  (
    label: 'Report an issue',
    short: 'Report',
    icon: Icons.add_circle_outline,
    selected: Icons.add_circle,
    route: '/report_issue'
  ),
  (
    label: 'My reports',
    short: 'Reports',
    icon: Icons.assignment_outlined,
    selected: Icons.assignment,
    route: '/my_reports'
  ),
  (
    label: 'My account',
    short: 'Account',
    icon: Icons.person_outline,
    selected: Icons.person,
    route: '/profile'
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.currentIndex, required this.child});
  final int currentIndex;
  final Widget child;

  void _navigate(BuildContext context, int index) {
    final route = _destinations[index].route;
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      final rail = constraints.maxWidth >= 760;
      return Scaffold(
        body: SafeArea(
            bottom: false,
            child: Row(children: [
              if (rail)
                Container(
                    width: wide ? 252 : 88,
                    decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                            right: BorderSide(color: colors.outlineVariant))),
                    child: _sidebar(context, wide)),
              Expanded(
                  child: Column(children: [
                Container(
                    decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                            bottom: BorderSide(color: colors.outlineVariant))),
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 36 : 16, vertical: 10),
                    child: Row(children: [
                      if (!rail)
                        const BrandMark(compact: true)
                      else
                        Icon(Icons.location_on_outlined,
                            color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Fateh Jang',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('Your community, connected',
                                style: Theme.of(context).textTheme.bodySmall)
                          ])),
                      if (wide) ...[
                        Text(
                            DateFormat('EEE, d MMM yyyy')
                                .format(DateTime.now()),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 20)
                      ],
                      IconButton(
                          tooltip: 'Change appearance',
                          icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 21),
                          onPressed: () => AppSession.instance.setThemeMode(
                              Theme.of(context).brightness == Brightness.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark)),
                      IconButton(
                          tooltip: 'Notifications',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/notifications'),
                          icon: const Icon(Icons.notifications_outlined,
                              size: 23)),
                      if (wide) ...[
                        const SizedBox(width: 12),
                        Tooltip(
                            message: 'My account',
                            child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => _navigate(context, 4),
                                child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            colors.primaryContainer,
                                        child: Text(_initials,
                                            style: TextStyle(
                                                color: colors.primary,
                                                fontWeight:
                                                    FontWeight.w700))))))
                      ],
                    ])),
                if (AppSession.instance.isPreview)
                  Material(
                      color: colors.secondaryContainer,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          child: Row(children: [
                            Icon(Icons.visibility_outlined,
                                size: 18, color: colors.onSecondaryContainer),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Demo workspace · Sample data',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color:
                                                colors.onSecondaryContainer))),
                            TextButton(
                                onPressed: () {
                                  AppSession.instance.leavePreview();
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, '/', (_) => false);
                                },
                                child: const Text('Exit demo'))
                          ]))),
                Expanded(child: child),
              ])),
            ])),
        bottomNavigationBar: rail
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: colors.outlineVariant))),
                child: NavigationBar(
                    selectedIndex: currentIndex.clamp(0, 4),
                    onDestinationSelected: (i) => _navigate(context, i),
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selected),
                            label: d.short)
                    ])),
      );
    });
  }

  String get _initials {
    final name = AppSession.instance.isPreview
        ? 'Ayesha Khan'
        : globalCitizenUser?.fullName ?? 'Citizen';
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
  }

  Widget _sidebar(BuildContext context, bool wide) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding:
              EdgeInsets.symmetric(horizontal: wide ? 24 : 20, vertical: 28),
          child: BrandMark(compact: !wide)),
      if (wide)
        Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 24, 12),
            child: Text('YOUR COMMUNITY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant, letterSpacing: 1.4))),
      Expanded(
          child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 12),
              child: Column(children: [
                for (var i = 0; i < _destinations.length; i++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _navItem(context, i, wide))
              ]))),
      if (wide)
        Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.handshake_outlined, color: colors.primary),
                      const SizedBox(height: 12),
                      Text('Better, together.',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                          'Small actions make a lasting difference in your neighbourhood.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => showCommunityGuide(context),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('How it works'),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, size: 16)
                              ]))
                    ]))),
      Padding(
          padding: EdgeInsets.all(wide ? 24 : 12),
          child: wide
              ? Text('CivicConnect\nMade for your neighbourhood',
                  style: Theme.of(context).textTheme.bodySmall)
              : IconButton(
                  tooltip: 'How reporting works',
                  onPressed: () => showCommunityGuide(context),
                  icon: const Icon(Icons.help_outline))),
    ]);
  }

  Widget _navItem(BuildContext context, int index, bool wide) {
    final d = _destinations[index];
    final selected = index == currentIndex;
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;
    return Semantics(
        selected: selected,
        button: true,
        label: d.label,
        child: Tooltip(
            message: wide ? '' : d.label,
            child: Material(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigate(context, index),
                    child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: wide ? 16 : 12, vertical: 16),
                        child: Row(
                            mainAxisAlignment: wide
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Icon(selected ? d.selected : d.icon,
                                  color: foreground, size: 22),
                              if (wide) ...[
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Text(d.label,
                                        style: TextStyle(
                                            color: foreground,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w500)))
                              ]
                            ]))))));
  }
}

void showCommunityGuide(BuildContext context) {
  showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('A better neighbourhood starts here.',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    for (final step in [
                      (
                        Icons.add_a_photo_outlined,
                        '1. Spot and report',
                        'Add clear photos, a short description, and the exact location.'
                      ),
                      (
                        Icons.assignment_outlined,
                        '2. Follow your report',
                        'Find your reference code and progress in My Reports.'
                      ),
                      (
                        Icons.people_outline,
                        '3. Support your community',
                        'Explore existing issues and support reports that matter to you.'
                      )
                    ])
                      Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(step.$1,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(step.$2,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 4),
                                      Text(step.$3)
                                    ]))
                              ])),
                    const InlineNotice(
                        message:
                            'For an immediate danger or emergency, contact your local emergency services. CivicConnect is for community issue reporting.'),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it')))
                  ]))));
}
