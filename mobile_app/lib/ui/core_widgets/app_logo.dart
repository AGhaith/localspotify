import 'package:flutter/material.dart';

/// Next-Generation Ultra-Modern SpotifyPROMAX & LocalSpotify Emblem
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
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF1ED760).withValues(alpha: 0.35),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.02,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: const Color(0xFF00F5D4).withValues(alpha: 0.20),
                  blurRadius: size * 0.25,
                  offset: Offset(-size * 0.05, -size * 0.05),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // 1. Dark Cyber Glass Background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  radius: 1.2,
                  colors: [
                    Color(0xFF152238),
                    Color(0xFF0B101B),
                    Color(0xFF05070D),
                  ],
                ),
              ),
            ),

            // 2. Subtle Glow Mesh in the center
            Positioned.fill(
              child: Center(
                child: Container(
                  width: size * 0.7,
                  height: size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF1ED760).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Custom Futuristic Sonic Pulse & Play Emblem
            Center(
              child: CustomPaint(
                size: Size(size * 0.65, size * 0.65),
                painter: _SonicPulseEmblemPainter(),
              ),
            ),

            // 4. Glassmorphism Top-Edge Highlight / Sheen
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.45,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Outer Gradient Border Ring
            if (showBorder)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      width: size * 0.028,
                      color: const Color(0xFF1ED760).withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SonicPulseEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gradient Shader for Sonic Sound Waves
    const waveGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF00F5D4),
        Color(0xFF1ED760),
        Color(0xFF22C55E),
      ],
    );

    final wavePaint = Paint()
      ..shader = waveGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 1. Top Wide Dynamic Sonic Wave
    wavePaint.strokeWidth = w * 0.11;
    final topPath = Path();
    topPath.moveTo(w * 0.16, h * 0.32);
    topPath.cubicTo(
      w * 0.38, h * 0.16,
      w * 0.68, h * 0.18,
      w * 0.88, h * 0.34,
    );
    canvas.drawPath(topPath, wavePaint);

    // 2. Middle Sonic Wave
    wavePaint.strokeWidth = w * 0.105;
    final midPath = Path();
    midPath.moveTo(w * 0.22, h * 0.50);
    midPath.cubicTo(
      w * 0.40, h * 0.38,
      w * 0.64, h * 0.39,
      w * 0.82, h * 0.52,
    );
    canvas.drawPath(midPath, wavePaint);

    // 3. Lower Sonic Wave
    wavePaint.strokeWidth = w * 0.095;
    final btmPath = Path();
    btmPath.moveTo(w * 0.28, h * 0.68);
    btmPath.cubicTo(
      w * 0.44, h * 0.59,
      w * 0.60, h * 0.60,
      w * 0.74, h * 0.70,
    );
    canvas.drawPath(btmPath, wavePaint);

    // 4. Center Mini Holographic Play Pulse Dot / Accent
    final dotPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFF1ED760),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.84), radius: w * 0.08))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.5, h * 0.84), w * 0.055, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
