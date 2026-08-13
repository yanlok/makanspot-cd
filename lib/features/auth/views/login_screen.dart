import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/constants/demo_accounts.dart';
import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authControllerProvider.notifier)
        .login(_emailController.text, _passwordController.text);
    // Navigation is handled by the router redirect once the session exists.
  }

  /// Fills the form with a demo account and submits it immediately.
  void _quickLogin(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return AuthLayout(
      icon: LucideIcons.logIn,
      title: 'Welcome back',
      subtitle: 'Log in to your MakanSpot account',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          const Text("Don't have an account? "),
          AuthLinkButton(
            label: 'Create one',
            buttonKey: const Key('create-account-link'),
            onPressed: () => context.go('/register'),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.registrationSucceeded)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.medium),
              child: Semantics(
                liveRegion: true,
                child: const Text(
                  'Account created. Log in to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ),
          AuthErrorMessage(state.errorMessage),
          AuthTextField(
            label: 'Email',
            hint: 'you@example.com',
            icon: LucideIcons.mail,
            controller: _emailController,
            fieldKey: const Key('login-email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            errorText: state.emailError,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _passwordController,
            fieldKey: const Key('login-password'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            trailing: AuthLinkButton(
              label: 'Forgot password?',
              fontSize: 12,
              buttonKey: const Key('forgot-password-link'),
              onPressed: () => context.go('/forgot-password'),
            ),
            onSubmitted: (_) => _submit(),
            errorText: state.passwordError,
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: 'Log in',
            loadingLabel: 'Signing in...',
            isLoading: state.isSubmitting,
            onPressed: _submit,
            buttonKey: const Key('login-submit'),
          ),
          const SizedBox(height: AppSpacing.large),
          const Text(
            'Quick login (development)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('quick-login-user'),
                  onPressed: () => _quickLogin(
                    DemoAccounts.userEmail,
                    DemoAccounts.userPassword,
                  ),
                  icon: const Icon(LucideIcons.user, size: 16),
                  label: const Text('User'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('quick-login-admin'),
                  onPressed: () => _quickLogin(
                    DemoAccounts.adminEmail,
                    DemoAccounts.adminPassword,
                  ),
                  icon: const Icon(LucideIcons.shield, size: 16),
                  label: const Text('Admin'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
