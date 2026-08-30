import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/auth_provider.dart';
import '../../core_widgets/neo_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverUrlController = TextEditingController(text: 'http://100.92.248.49:6767');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    final serverUrl = _serverUrlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (serverUrl.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter server URL and username'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Login failed. Check server address.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.checking;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.textDark,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'LocalSpotify',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect to your Navidrome / Subsonic music vault',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 36),

                // Server Address Input
                Text('SERVER ADDRESS', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverUrlController,
                  keyboardType: TextInputType.url,
                  style: AppTypography.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'e.g. http://100.92.248.49:6767',
                    prefixIcon: Icon(Icons.language_rounded, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),

                // Username Input
                Text('USERNAME', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: AppTypography.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Enter your Subsonic username',
                    prefixIcon: Icon(Icons.person_rounded, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Input
                Text('PASSWORD', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Connect Button
                NeoButton(
                  text: 'Connect to Server',
                  icon: Icons.login_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
