import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _resendRequested = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return AuthLayout(
      icon: LucideIcons.mail,
      title: 'Reset password',
      subtitle: "We'll send you a link to reset it",
      footer: AuthLinkButton(
        label: 'Back to log in',
        icon: LucideIcons.arrowLeft,
        buttonKey: const Key('back-to-login-link'),
        onPressed: () => context.go('/login'),
      ),
      child: state.passwordResetSent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'If an account exists with that email, you\'ll receive a '
                  'password reset link shortly.',
                  textAlign: TextAlign.center,
                ),
                if (_resendRequested) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'Check your email for the new link.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                AuthLinkButton(
                  label: 'Resend email',
                  icon: LucideIcons.refreshCw,
                  buttonKey: const Key('resend-reset-link'),
                  onPressed: () {
                    setState(() => _resendRequested = true);
                    _submit();
                  },
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthErrorMessage(state.errorMessage),
                AuthTextField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  icon: LucideIcons.mail,
                  controller: _emailController,
                  fieldKey: const Key('forgot-password-email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  errorText: state.emailError,
                ),
                const SizedBox(height: 16),
                AuthSubmitButton(
                  label: 'Send reset link',
                  loadingLabel: 'Sending...',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                  buttonKey: const Key('send-reset-link'),
                ),
              ],
            ),
    );
  }

  void _submit() {
    ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_emailController.text);
  }
}
