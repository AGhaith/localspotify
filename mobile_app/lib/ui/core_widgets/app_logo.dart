import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final bool showBorder;

  const AppLogo({
    super.key,
    this.size = 56,
    this.showGlow = true,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: const Color(0xFF333333), width: size * 0.028)
            : null,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.65),
          painter: _VinylDotPainter(),
        ),
      ),
    );
  }
}

class _VinylDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius * 0.7,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.16, -radius * 0.16),
      radius * 0.18,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
