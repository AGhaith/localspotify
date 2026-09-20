import 'package:flutter/material.dart';

/// Modern Spotify-styled Sound Wave Emblem & App Logo
class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AppLogo({
    super.key,
    this.size = 56,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF22C55E),
            Color(0xFF16A34A),
          ],
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: size * 0.15,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: _SpotifyWavePainter(),
        ),
      ),
    );
  }
}

class _SpotifyWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top arc (wide)
    paint.strokeWidth = w * 0.16;
    final topRect = Rect.fromCenter(
      center: Offset(w * 0.48, h * 0.76),
      width: w * 1.05,
      height: h * 1.05,
    );
    canvas.drawArc(topRect, -2.45, 1.25, false, paint);

    // Middle arc
    paint.strokeWidth = w * 0.15;
    final midRect = Rect.fromCenter(
      center: Offset(w * 0.48, h * 0.84),
      width: w * 0.82,
      height: h * 0.82,
    );
    canvas.drawArc(midRect, -2.5, 1.3, false, paint);

    // Bottom arc (small)
    paint.strokeWidth = w * 0.14;
    final btmRect = Rect.fromCenter(
      center: Offset(w * 0.48, h * 0.92),
      width: w * 0.60,
      height: h * 0.60,
    );
    canvas.drawArc(btmRect, -2.55, 1.35, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
