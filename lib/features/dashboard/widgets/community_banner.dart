import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CommunityBanner extends StatelessWidget {
  const CommunityBanner({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final wide =
            c.maxWidth > 650 && MediaQuery.textScalerOf(context).scale(1) < 1.5;
        return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: AppTheme.evergreen,
                borderRadius: BorderRadius.circular(22)),
            child: Stack(children: [
              if (wide)
                Positioned(
                    right: -8,
                    bottom: 0,
                    top: 0,
                    width: c.maxWidth * .43,
                    child: ExcludeSemantics(
                        child: CustomPaint(painter: _NeighbourhoodPainter()))),
              Padding(
                  padding: EdgeInsets.all(wide ? 32 : 24),
                  child: SizedBox(
                      width: wide ? c.maxWidth * .55 : null,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFD9C58A),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Expanded(
                                  child: Text('A BETTER PLACE TO CALL HOME',
                                      style: TextStyle(
                                          color: Color(0xFFDCE9D9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.1)))
                            ]),
                            const SizedBox(height: 16),
                            Text('Your neighbourhood.\nYour difference.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontSize: wide ? 32 : 28)),
                            const SizedBox(height: 12),
                            const Text(
                                'A safer street. A cleaner lane. A small action today can make everyday life better for everyone.',
                                style: TextStyle(
                                    color: Color(0xFFDCE9D9),
                                    fontSize: 14,
                                    height: 1.65)),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                                onPressed: () => Navigator.pushReplacementNamed(
                                    context, '/report_issue'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFE9EDDE),
                                    foregroundColor: AppTheme.evergreen),
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Report an issue')),
                          ]))),
            ]));
      });
}

/// A small architectural streetscape: the application's one illustrative accent.
class _NeighbourhoodPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360;
    final sy = size.height / 270;
    canvas.save();
    canvas.scale(sx, sy);
    final line = Paint()
      ..color = const Color(0xFF799883)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final light = Paint()..color = const Color(0xFFD8DDAB);
    final deep = Paint()..color = const Color(0xFF245B46);
    final middle = Paint()..color = const Color(0xFF3F7155);
    canvas.drawCircle(
        const Offset(240, 72), 32, Paint()..color = const Color(0xFF4E7150));
    canvas.drawLine(const Offset(10, 249), const Offset(370, 249), line);
    canvas.drawLine(const Offset(5, 262), const Offset(345, 262), line);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(78, 110, 82, 138), const Radius.circular(2)),
        middle);
    canvas.drawRect(const Rect.fromLTWH(166, 74, 101, 174), deep);
    canvas.drawRect(const Rect.fromLTWH(166, 74, 101, 174), line);
    canvas.drawRect(const Rect.fromLTWH(170, 69, 93, 5), middle);
    canvas.drawRect(const Rect.fromLTWH(275, 146, 69, 102), middle);
    final roof = Path()
      ..moveTo(269, 146)
      ..lineTo(309, 115)
      ..lineTo(350, 146)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF668267));
    for (var y = 92.0; y < 214; y += 29) {
      for (var x = 182.0; x < 250; x += 28) {
        canvas.drawRect(
            Rect.fromLTWH(x, y, 12, 17), (x + y) % 3 < 1 ? light : middle);
      }
    }
    for (var y = 128.0; y < 210; y += 31) {
      for (var x = 90.0; x < 150; x += 25) {
        canvas.drawRect(Rect.fromLTWH(x, y, 12, 16),
            light..color = const Color(0xFFBDCCA2));
      }
    }
    canvas.drawRect(const Rect.fromLTWH(292, 166, 13, 20), light);
    canvas.drawRect(const Rect.fromLTWH(317, 166, 13, 20), light);
    canvas.drawRect(const Rect.fromLTWH(301, 210, 17, 38), deep);
    canvas.drawRect(const Rect.fromLTWH(206, 220, 21, 28), middle);
    canvas.drawLine(const Offset(44, 170), const Offset(44, 249), line);
    canvas.drawOval(const Rect.fromLTWH(17, 124, 54, 68),
        Paint()..color = const Color(0xFF6D8C66));
    canvas.drawLine(const Offset(44, 165), const Offset(44, 226), line);
    canvas.drawLine(const Offset(43, 192), const Offset(30, 177), line);
    canvas.drawLine(const Offset(44, 179), const Offset(56, 167), line);
    canvas.drawLine(const Offset(130, 212), const Offset(130, 249), line);
    canvas.drawLine(const Offset(116, 212), const Offset(143, 212), line);
    canvas.drawCircle(
        const Offset(130, 208), 5, Paint()..color = const Color(0xFFE0D7A8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
