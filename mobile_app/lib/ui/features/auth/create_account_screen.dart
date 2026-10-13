import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/auth_provider.dart';
import '../../core_widgets/app_logo.dart';
import '../../core_widgets/neo_button.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.createAccount(
      serverUrl: AppConfig.serverUrl,
      username: _username.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _error = auth.errorMessage ?? 'Failed to create account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().status == AuthStatus.checking;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      )),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 64)),
                const SizedBox(height: AppSpacing.xl),
                Text('Create account',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium),
                const SizedBox(height: AppSpacing.xxl),
                Text('USERNAME', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _username,
                  validator: (value) => value != null &&
                          RegExp(r'^[a-zA-Z0-9_.-]{3,32}$')
                              .hasMatch(value.trim())
                      ? null
                      : 'Use 3–32 letters, numbers, _, . or -',
                  decoration: const InputDecoration(
                      hintText: 'Username',
                      prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('EMAIL', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? null
                      : 'Enter a valid email address',
                  decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('PASSWORD', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  validator: (value) =>
                      value != null && value.length >= 8 && value.length <= 128
                          ? null
                          : 'Use 8–128 characters',
                  decoration: InputDecoration(
                    hintText: '8–128 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('CONFIRM PASSWORD', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _confirm,
                  obscureText: _hideConfirm,
                  validator: (value) =>
                      value == _password.text ? null : 'Passwords do not match',
                  decoration: InputDecoration(
                    hintText: 'Repeat your password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_hideConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () =>
                          setState(() => _hideConfirm = !_hideConfirm),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(_error!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.xl),
                NeoButton(
                  text: 'Create account',
                  icon: Icons.person_add_alt_1_rounded,
                  isLoading: loading,
                  onPressed: loading ? null : _createAccount,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Already have an account? ',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Log in')),
                ]),
              ],
            )),
      ))),
    );
  }
}
