import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';

import 'auth_fields.dart';
import 'auth_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            final introduction = Entrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A VOICE FOR YOUR COMMUNITY',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      'CivicConnect',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A little care.\nA better place to live.',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Notice something that needs attention? Report it, '
                    'keep track of your reports, and explore issues in your neighbourhood.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AsyncButton(
                    label: 'Get started',
                    icon: Icons.arrow_forward_outlined,
                    onPressed: () => Navigator.pushNamed(context, '/signUp'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 52),
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    style: authTextButtonStyle(),
                    onPressed: () {
                      AppSession.instance.enterPreview();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/dashboard',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Explore the demo'),
                  ),
                  TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/authority'),
                      icon: const Icon(Icons.admin_panel_settings_outlined,
                          size: 20),
                      label: const Text('Service-team workspace')),
                  const SizedBox(height: 8),
                  Text(
                    'The demo uses sample reports. No account needed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 40 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark(
                          compact: constraints.maxWidth < 360 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.2,
                        ),
                      ),
                      SizedBox(height: wide ? 64 : 40),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: introduction),
                            const SizedBox(width: 64),
                            const Expanded(child: AuthStory()),
                          ],
                        )
                      else ...[
                        introduction,
                        const SizedBox(height: 40),
                        const AuthStory(),
                      ],
                      const SizedBox(height: 40),
                      const Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _WelcomeFeature(
                            icon: Icons.add_location_alt_outlined,
                            label: 'Report local issues',
                          ),
                          _WelcomeFeature(
                            icon: Icons.fact_check_outlined,
                            label: 'Follow your reports',
                          ),
                          _WelcomeFeature(
                            icon: Icons.groups_outlined,
                            label: 'See your community',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      );
}
