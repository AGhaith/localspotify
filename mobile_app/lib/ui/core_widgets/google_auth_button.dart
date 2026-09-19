import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class GoogleAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const GoogleAuthButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onPressed?.call();
            },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GoogleLogo(size: 20),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pixel-perfect Google 'G' vector mark using CustomPainter
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = w * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final arcRect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // 1. Blue: Right arc & crossbar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -0.35, 1.2, false, paint);

    // Crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx - strokeWidth * 0.3, center.dy - strokeWidth / 2, radius * 0.95, strokeWidth),
      const Radius.circular(2),
    );
    canvas.drawRRect(barRect, barPaint);

    // 2. Green: Bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, 0.85, 1.6, false, paint);

    // 3. Yellow: Left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, 2.45, 1.35, false, paint);

    // 4. Red: Top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, 3.8, 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Interactive Google Account Selector Sheet
class GoogleAccountSelectorSheet extends StatefulWidget {
  final Function(String email, String displayName) onSelected;

  const GoogleAccountSelectorSheet({
    super.key,
    required this.onSelected,
  });

  static Future<void> show(BuildContext context, {required Function(String email, String displayName) onSelected}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GoogleAccountSelectorSheet(onSelected: onSelected),
    );
  }

  @override
  State<GoogleAccountSelectorSheet> createState() => _GoogleAccountSelectorSheetState();
}

class _GoogleAccountSelectorSheetState extends State<GoogleAccountSelectorSheet> {
  final _emailController = TextEditingController(text: 'ahmed.localspotify@gmail.com');
  final _nameController = TextEditingController(text: 'Ahmed Gaith');
  bool _customInput = false;

  final List<Map<String, String>> _accounts = [
    {
      'name': 'Ahmed Gaith',
      'email': 'ahmed.localspotify@gmail.com',
      'initial': 'A',
    },
    {
      'name': 'LocalSpotify User',
      'email': 'music.listener@gmail.com',
      'initial': 'L',
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF33364A), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const GoogleLogo(size: 24),
              const SizedBox(width: 12),
              Text(
                'Choose an account',
                style: AppTypography.titleLarge.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'to continue to LocalSpotify Music Vault',
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),

          if (!_customInput) ...[
            ..._accounts.map((acc) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 20,
                  child: Text(
                    acc['initial']!,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(acc['name']!, style: AppTypography.titleMedium),
                subtitle: Text(acc['email']!, style: AppTypography.bodySmall),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  widget.onSelected(acc['email']!, acc['name']!);
                },
              );
            }),
            const Divider(color: Colors.white12, height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF222432),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white70, size: 20),
              ),
              title: Text('Use another Google account', style: AppTypography.bodyMedium),
              onTap: () {
                setState(() => _customInput = true);
              },
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.badge_rounded, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Google Email',
                prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final email = _emailController.text.trim();
                final name = _nameController.text.trim();
                if (email.isNotEmpty) {
                  Navigator.pop(context);
                  widget.onSelected(email, name.isNotEmpty ? name : email.split('@').first);
                }
              },
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
