import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/auth_provider.dart';
import '../../core_widgets/app_logo.dart';
import '../../core_widgets/google_auth_button.dart';
import '../../core_widgets/neo_button.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both username and password'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      serverUrl: AppConfig.serverUrl,
      username: username,
      password: password,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Authentication failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onGoogleLogin() {
    GoogleAccountSelectorSheet.show(
      context,
      onSelected: (email, name) async {
        final auth = context.read<AuthProvider>();
        final success = await auth.loginWithGoogle(
          serverUrl: AppConfig.serverUrl,
          email: email,
          displayName: name,
        );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Google authentication failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
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
                const Center(
                  child: AppLogo(size: 72),
                ),
                const SizedBox(height: 24),
                Text(
                  'LocalSpotify',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Stream your personal music vault anywhere',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 40),

                // Username Input
                Text('USERNAME', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: AppTypography.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Enter your username',
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
                  text: 'Sign In',
                  icon: Icons.login_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onLogin,
                ),

                const SizedBox(height: 22),

                // OR Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('OR', style: AppTypography.labelSmall.copyWith(color: Colors.white54)),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),

                const SizedBox(height: 22),

                // Google Login Button (OAuth 2.0)
                GoogleAuthButton(
                  text: 'Continue with Google',
                  isLoading: isLoading,
                  onPressed: _onGoogleLogin,
                ),

                const SizedBox(height: 36),

                // Footer: Create Account Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Create one',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
