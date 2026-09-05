import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_layout.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

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
            errorText: state.passwordError,
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
            onSubmitted: (_) => _submit(),
            errorText: state.passwordError,
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: 'Reset password',
            loadingLabel: 'Resetting...',
            isLoading: state.isSubmitting,
            onPressed: _submit,
            buttonKey: const Key('reset-password-submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          token: '',
          password: _passwordController.text,
          confirmPassword: _confirmController.text,
        );
    if (succeeded && mounted) {
      context.go('/login');
    }
  }
}
