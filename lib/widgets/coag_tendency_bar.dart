import 'package:flutter/material.dart';
import '../theme/coag_theme.dart';

/// Custom-painted 3-zone gradient bar (HYPO | NORMAL | HYPER)
/// with a white triangle marker positioned by gammaAsymptote.
class CoagTendencyBar extends StatelessWidget {
  final double gammaAsymptote; // Hz — determines marker position

  const CoagTendencyBar({super.key, required this.gammaAsymptote});

  @override
  Widget build(BuildContext context) {
    // Gamma range: 10 (max HYPER) to 60 (max HYPO)
    // Zones: HYPER <22, NORMAL 22-38, HYPO >38
    // Map gammaAsymptote onto 0.0 - 1.0 within 10..60 range
    final position = ((gammaAsymptote - 10.0) / 50.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zone labels
        Row(
          children: [
            Expanded(
              flex: 24, // 12-22 = HYPER zone (24% of 10-60)
              child: Text('HYPER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: CoagTheme.hyperZone,
                      letterSpacing: 0.5)),
            ),
            Expanded(
              flex: 32, // 22-38 = NORMAL zone (32% of 10-60)
              child: Text('NORMAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: CoagTheme.normalZone,
                      letterSpacing: 0.5)),
            ),
            Expanded(
              flex: 44, // 38-60 = HYPO zone (44% of 10-60)
              child: Text('HYPO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: CoagTheme.hypoZone,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Gradient bar + triangle marker
        LayoutBuilder(builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final markerX = (position * barWidth).clamp(8.0, barWidth - 8.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient bar
              Container(
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(
                    colors: [
                      CoagTheme.hyperZone,  // red (HYPER left)
                      CoagTheme.normalZone, // green (NORMAL center)
                      CoagTheme.hypoZone,   // blue (HYPO right)
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Triangle marker
              Positioned(
                left: markerX - 8,
                top: -10,
                child: CustomPaint(
                  size: const Size(16, 10),
                  painter: _TrianglePainter(),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 6),
        // Scale labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('10 Hz', style: TextStyle(fontSize: 8, color: Colors.grey.withOpacity(0.7))),
            Text('22 Hz', style: TextStyle(fontSize: 8, color: Colors.grey.withOpacity(0.7))),
            Text('38 Hz', style: TextStyle(fontSize: 8, color: Colors.grey.withOpacity(0.7))),
            Text('60 Hz', style: TextStyle(fontSize: 8, color: Colors.grey.withOpacity(0.7))),
          ],
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
    // Subtle shadow
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
