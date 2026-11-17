import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';

/// Shared, scrollable authentication frame. The story moves out of the way on
/// small screens, leaving a readable form and room for the software keyboard.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.backRoute = '/welcome',
    this.onBack,
    this.backEnabled = true,
    this.storyTitle = 'A better neighbourhood\nstarts with you.',
    this.storyDescription =
        'Report a local issue, follow its progress, and see what matters to your community.',
  });

  final String title;
  final String description;
  final List<Widget> children;
  final String? backRoute;
  final VoidCallback? onBack;
  final bool backEnabled;
  final String storyTitle;
  final String storyDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
        canPop: backEnabled,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(wide ? 40 : 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (backRoute != null || onBack != null) ...[
                                IconButton(
                                  tooltip: 'Back',
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                    minWidth: 48,
                                  ),
                                  onPressed: !backEnabled
                                      ? null
                                      : onBack ??
                                          () {
                                            final navigator =
                                                Navigator.of(context);
                                            if (navigator.canPop()) {
                                              navigator.pop();
                                            } else {
                                              navigator.pushReplacementNamed(
                                                backRoute!,
                                              );
                                            }
                                          },
                                  icon: const Icon(Icons.arrow_back_outlined),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Flexible(
                                child: BrandMark(
                                  compact: constraints.maxWidth < 420 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(1) >
                                          1.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: wide ? 48 : 32),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AuthStory(
                                    title: storyTitle,
                                    description: storyDescription,
                                  ),
                                ),
                                const SizedBox(width: 64),
                                Expanded(child: _form(theme)),
                              ],
                            )
                          else
                            Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 480),
                                child: _form(theme),
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ));
  }

  Widget _form(ThemeData theme) {
    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }
}

class AuthStory extends StatelessWidget {
  const AuthStory({
    super.key,
    this.title = 'Your neighbourhood.\nOur shared future.',
    this.description =
        'Small actions begin with noticing. Make your voice part of the picture.',
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_city_outlined,
              color: colors.onPrimaryContainer,
              size: 32,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onPrimaryContainer,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ExcludeSemantics(
              child: AspectRatio(
                aspectRatio: 1.55,
                child: CustomPaint(painter: _NeighbourhoodPainter(colors)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NOTICE  /  REPORT  /  FOLLOW THROUGH',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small architectural illustration drawn locally, with no network assets.
class _NeighbourhoodPainter extends CustomPainter {
  const _NeighbourhoodPainter(this.colors);
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 480, size.height / 310);
    final line = Paint()
      ..color = colors.onPrimaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final fill = Paint()..color = colors.surface;
    final green = Paint()..color = colors.primary;
    final soft = Paint()..color = colors.secondaryContainer;
    canvas.drawCircle(const Offset(394, 52), 29, soft);
    canvas.drawLine(const Offset(8, 258), const Offset(472, 258), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 112, 104, 146),
        const Radius.circular(5),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 112, 104, 146),
        const Radius.circular(5),
      ),
      line,
    );
    final roof = Path()
      ..moveTo(20, 112)
      ..lineTo(86, 58)
      ..lineTo(152, 112)
      ..close();
    canvas.drawPath(roof, green);
    canvas.drawPath(roof, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(166, 72, 132, 186),
        const Radius.circular(6),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(166, 72, 132, 186),
        const Radius.circular(6),
      ),
      line,
    );
    canvas.drawRect(const Rect.fromLTWH(178, 60, 108, 12), green);
    for (final x in [187.0, 251.0]) {
      for (final y in [100.0, 148.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 26, 30),
            const Radius.circular(3),
          ),
          soft,
        );
        canvas.drawLine(Offset(x + 13, y), Offset(x + 13, y + 30), line);
      }
    }
    for (final x in [52.0, 98.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 141, 22, 29), soft);
      canvas.drawRect(Rect.fromLTWH(x, 141, 22, 29), line);
    }
    canvas.drawRect(const Rect.fromLTWH(71, 208, 30, 50), green);
    canvas.drawRect(const Rect.fromLTWH(215, 208, 34, 50), green);
    canvas.drawLine(const Offset(349, 138), const Offset(349, 258), line);
    canvas.drawCircle(const Offset(349, 135), 40, green);
    canvas.drawCircle(const Offset(330, 153), 26, green);
    canvas.drawCircle(const Offset(370, 151), 28, green);
    canvas.drawLine(const Offset(349, 188), const Offset(349, 250), line);
    canvas.drawLine(const Offset(414, 125), const Offset(414, 258), line);
    canvas.drawLine(const Offset(414, 125), const Offset(442, 125), line);
    canvas.drawCircle(const Offset(440, 130), 9, soft);
    canvas.drawLine(const Offset(16, 280), const Offset(330, 280), line);
    canvas.drawLine(const Offset(358, 280), const Offset(462, 280), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NeighbourhoodPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
