import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_layout.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.token, super.key});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      return AuthLayout(
        icon: LucideIcons.triangleAlert,
        title: 'Invalid reset link',
        subtitle: 'This password reset link is missing or invalid',
        footer: AuthLinkButton(
          label: 'Request a new link',
          buttonKey: const Key('request-new-reset-link'),
          onPressed: () => context.go('/forgot-password'),
        ),
        child: const Text(
          'The link you used appears to be incomplete. Please request a new '
          'password reset email.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final state = ref.watch(authControllerProvider);
    return AuthLayout(
      icon: LucideIcons.lock,
      title: 'New password',
      subtitle: 'Enter your new password below',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthErrorMessage(state.errorMessage),
          AuthTextField(
            label: 'New Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _passwordController,
            fieldKey: const Key('new-password'),
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Confirm Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _confirmController,
            fieldKey: const Key('confirm-new-password'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(token),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: 'Reset password',
            loadingLabel: 'Resetting...',
            isLoading: state.isLoading,
            onPressed: () => _submit(token),
            buttonKey: const Key('reset-password-submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(String token) async {
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          token: token,
          password: _passwordController.text,
          confirmPassword: _confirmController.text,
        );
    if (succeeded && mounted) {
      context.go('/login');
    }
  }
}
