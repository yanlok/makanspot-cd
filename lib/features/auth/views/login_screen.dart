import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/shared/widgets/demo_mode_switcher.dart';

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
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .login(_emailController.text, _passwordController.text);
    if (succeeded && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Stack(
      children: [
        AuthLayout(
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
                isLoading: state.isLoading,
                onPressed: _submit,
                buttonKey: const Key('login-submit'),
              ),
            ],
          ),
        ),
        const Positioned(top: 0, right: 0, child: DemoModeSwitcher()),
      ],
    );
  }
}
