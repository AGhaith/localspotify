import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/auth_provider.dart';
import '../../core_widgets/app_logo.dart';
import '../../core_widgets/neo_button.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      serverUrl: AppConfig.serverUrl,
      username: username,
      password: password,
    );

    if (!success && mounted) {
      setState(() => _error = auth.errorMessage ?? 'Authentication failed');
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
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Header
                  const Center(
                    child: AppLogo(size: 72),
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
                  const SizedBox(height: AppSpacing.xxl),

                  Text('USERNAME', style: AppTypography.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _usernameController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your username'
                        : null,
                    style: AppTypography.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'Enter your username',
                      prefixIcon: Icon(Icons.person_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('PASSWORD', style: AppTypography.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _passwordController,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password'
                        : null,
                    obscureText: _obscurePassword,
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(_error!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.xxl),

                  NeoButton(
                    text: 'Log in',
                    icon: Icons.login_rounded,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _onLogin,
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAccountScreen(),
                            ),
                          );
                        },
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
