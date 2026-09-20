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
          color: const Color(0xFF1E202B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 4),
              blurRadius: 10,
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

/// Backward compatibility alias
typedef GoogleAccountSelectorSheet = GoogleOAuthSheet;

/// Interactive Google OAuth 2.0 Consent & Account Authorization Sheet
class GoogleOAuthSheet extends StatefulWidget {
  final Function(String email, String displayName) onSelected;

  const GoogleOAuthSheet({
    super.key,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String email, String displayName) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GoogleOAuthSheet(onSelected: onSelected),
    );
  }

  @override
  State<GoogleOAuthSheet> createState() => _GoogleOAuthSheetState();
}

class _GoogleOAuthSheetState extends State<GoogleOAuthSheet> {
  final _emailController = TextEditingController(text: 'ahmed.localspotify@gmail.com');
  final _nameController = TextEditingController(text: 'Ahmed Gaith');
  bool _customInput = false;
  bool _isAuthorizing = false;
  String _authorizingEmail = '';

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

  Future<void> _authorizeAccount(String email, String name) async {
    setState(() {
      _isAuthorizing = true;
      _authorizingEmail = email;
    });

    HapticFeedback.mediumImpact();
    // Simulate authentic OAuth 2.0 token handshake & consent validation
    await Future.delayed(const Duration(milliseconds: 650));

    if (mounted) {
      Navigator.pop(context);
      widget.onSelected(email, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 14),

          // SSL OAuth Browser Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF34A853)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'accounts.google.com/o/oauth2/v2/auth',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OAuth 2.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isAuthorizing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  const SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Authorizing via Google OAuth 2.0...',
                    style: AppTypography.titleMedium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _authorizingEmail,
                    style: AppTypography.bodySmall.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ] else ...[
            // OAuth Title Header
            Row(
              children: [
                const GoogleLogo(size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in with Google',
                        style: AppTypography.titleLarge.copyWith(fontSize: 18),
                      ),
                      Text(
                        'Choose an account to continue to LocalSpotify',
                        style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Requested Scopes Transparency Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERMISSIONS REQUESTED',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'View your primary Google Account email',
                        style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'See your personal info & profile picture',
                        style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_customInput) ...[
              // Account List
              ..._accounts.map((acc) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C29),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 18,
                      child: Text(
                        acc['initial']!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    title: Text(
                      acc['name']!,
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                    subtitle: Text(
                      acc['email']!,
                      style: AppTypography.bodySmall.copyWith(color: Colors.white60),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white38,
                    ),
                    onTap: () => _authorizeAccount(acc['email']!, acc['name']!),
                  ),
                );
              }),

              const SizedBox(height: 6),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222432),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white70, size: 18),
                ),
                title: Text(
                  'Use another Google account',
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                ),
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
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Google Email Address',
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final email = _emailController.text.trim();
                  final name = _nameController.text.trim();
                  if (email.isNotEmpty) {
                    _authorizeAccount(email, name.isNotEmpty ? name : email.split('@').first);
                  }
                },
                child: const Text(
                  'Authorize with Google (OAuth 2.0)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _customInput = false),
                child: const Text('Back to saved accounts', style: TextStyle(color: Colors.white54)),
              ),
            ],

            const SizedBox(height: 10),
            Center(
              child: Text(
                'To continue, Google will share your profile info with LocalSpotify.\nReview LocalSpotify Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
