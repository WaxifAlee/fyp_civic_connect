import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/app/app_shell.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 4,
      child: CivicPage(
        title: 'Notifications',
        description: 'A place for updates about your account and reports.',
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/profile'),
            icon: const Icon(Icons.person_outline),
            label: const Text('Your account'),
          ),
        ],
        children: [
          Entrance(
            child: AppPanel(
              child: EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'You’re all caught up',
                message: 'There are no notifications to show. To check the '
                    'current status of a report you submitted, open My Reports.',
                actionLabel: 'Go to My Reports',
                onAction: () =>
                    Navigator.pushReplacementNamed(context, '/my_reports'),
              ),
            ),
          ),
          const AppPanel(
            child: SectionHeading(
              title: 'Looking for a report update?',
              subtitle: 'My Reports is the place to follow your submissions '
                  'and view their latest status.',
            ),
          ),
        ],
      ),
    );
  }
}
