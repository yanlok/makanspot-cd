import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/router/app_router.dart';

import '../controllers/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .register(
          rawEmail: _emailController.text,
          rawPassword: _passwordController.text,
          confirmPassword: _confirmController.text,
        );
    if (!succeeded || !mounted) {
      return;
    }
    // With a usable session the router redirect moves on to the dashboard;
    // otherwise the account needs a manual sign-in on the Login screen.
    if (ref.read(authControllerProvider).session == null) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return AuthLayout(
      icon: LucideIcons.userPlus,
      title: 'Create your account',
      subtitle: 'Sign up to get started',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          const Text('Already have an account? '),
          AuthLinkButton(
            label: 'Log in',
            buttonKey: const Key('register-login-link'),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthErrorMessage(state.errorMessage),
          AuthTextField(
            label: 'Email',
            hint: 'you@example.com',
            icon: LucideIcons.mail,
            controller: _emailController,
            fieldKey: const Key('register-email'),
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
            fieldKey: const Key('register-password'),
            obscureText: true,
            textInputAction: TextInputAction.next,
            errorText: state.passwordError,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Confirm Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _confirmController,
            fieldKey: const Key('register-confirm-password'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitRegistration(),
            errorText: state.confirmPasswordError,
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: 'Create account',
            loadingLabel: 'Creating account...',
            isLoading: state.isSubmitting,
            onPressed: _submitRegistration,
            buttonKey: const Key('register-submit'),
          ),
        ],
      ),
    );
  }
}
