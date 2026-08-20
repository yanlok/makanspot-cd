import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/router/app_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/change_password_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_layout.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      return;
    }
    ref
        .read(changePasswordControllerProvider.notifier)
        .changePassword(
          email: session.email,
          currentPassword: _currentController.text,
          newPassword: _newController.text,
          confirmPassword: _confirmController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    if (state.succeeded) {
      return AuthLayout(
        icon: LucideIcons.shieldCheck,
        title: 'Password updated',
        subtitle: 'Your password has been changed',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use your new password the next time you sign in.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AuthSubmitButton(
              label: 'Back to profile',
              loadingLabel: '',
              isLoading: false,
              // The profile menu navigates here with `go`, so the stack has
              // no entry to pop; go back to the profile route explicitly.
              onPressed: () => context.go(AppRoutes.profile),
              buttonKey: const Key('change-password-done'),
            ),
          ],
        ),
      );
    }
    return AuthLayout(
      icon: LucideIcons.lock,
      title: 'Change password',
      subtitle: 'Choose a new password for your account',
      footer: AuthLinkButton(
        label: 'Back to profile',
        icon: LucideIcons.arrowLeft,
        buttonKey: const Key('change-password-back'),
        onPressed: () => context.go(AppRoutes.profile),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthErrorMessage(state.errorMessage),
          AuthTextField(
            label: 'Current Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _currentController,
            fieldKey: const Key('change-password-current'),
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofocus: true,
            errorText: state.currentPasswordError,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'New Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _newController,
            fieldKey: const Key('change-password-new'),
            obscureText: true,
            textInputAction: TextInputAction.next,
            errorText: state.newPasswordError,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Confirm New Password',
            hint: '••••••••',
            icon: LucideIcons.lock,
            controller: _confirmController,
            fieldKey: const Key('change-password-confirm'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            errorText: state.confirmPasswordError,
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: 'Update password',
            loadingLabel: 'Updating...',
            isLoading: state.isSubmitting,
            onPressed: _submit,
            buttonKey: const Key('change-password-submit'),
          ),
        ],
      ),
    );
  }
}
