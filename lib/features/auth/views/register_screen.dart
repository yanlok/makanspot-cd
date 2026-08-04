import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
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
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    if (state.awaitingOtp) {
      return _buildOtp(state);
    }
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
            isLoading: state.isLoading,
            onPressed: _submitRegistration,
            buttonKey: const Key('register-submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtp(AuthState state) {
    return AuthLayout(
      icon: LucideIcons.mail,
      title: 'Verify your email',
      subtitle: 'We sent a code to ${state.registrationEmail}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthErrorMessage(state.errorMessage),
          TextField(
            key: const Key('registration-otp'),
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 12,
            ),
            decoration: const InputDecoration(counterText: ''),
            onSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: 24),
          AuthSubmitButton(
            label: 'Verify',
            loadingLabel: 'Verifying...',
            isLoading: state.isLoading,
            onPressed: _verifyOtp,
            buttonKey: const Key('verify-otp'),
          ),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              const Text("Didn't receive the code? "),
              AuthLinkButton(
                label: 'Resend',
                buttonKey: const Key('resend-otp'),
                onPressed: () {
                  ref.read(authControllerProvider.notifier).resendOtp();
                },
              ),
            ],
          ),
          if (state.resendConfirmation != null)
            Semantics(
              liveRegion: true,
              child: Text(
                state.resendConfirmation!,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _submitRegistration() {
    ref
        .read(authControllerProvider.notifier)
        .register(
          rawEmail: _emailController.text,
          rawPassword: _passwordController.text,
          confirmPassword: _confirmController.text,
        );
  }

  Future<void> _verifyOtp() async {
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_otpController.text);
    if (succeeded && mounted) {
      context.go('/');
    }
  }
}
