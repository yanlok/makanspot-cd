import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/shared/widgets/demo_mode_switcher.dart';

import '../../auth/views/widgets/auth_controls.dart';
import '../../auth/views/widgets/auth_layout.dart';
import '../controllers/admin_auth_controller.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
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
        .read(adminAuthControllerProvider.notifier)
        .login(_emailController.text, _passwordController.text);
    if (succeeded && mounted) {
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAuthControllerProvider);
    return Stack(
      children: [
        AuthLayout(
          icon: LucideIcons.logIn,
          title: 'Admin login',
          subtitle: 'Sign in to the MakanSpot admin console',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthErrorMessage(state.errorMessage),
              AuthTextField(
                label: 'Email',
                hint: 'you@example.com',
                icon: LucideIcons.mail,
                controller: _emailController,
                fieldKey: const Key('admin-login-email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Password',
                hint: '••••••••',
                icon: LucideIcons.lock,
                controller: _passwordController,
                fieldKey: const Key('admin-login-password'),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              AuthSubmitButton(
                label: 'Log in as admin',
                loadingLabel: 'Signing in...',
                isLoading: state.isLoading,
                onPressed: _submit,
                buttonKey: const Key('admin-login-submit'),
              ),
            ],
          ),
        ),
        const Positioned(top: 0, right: 0, child: DemoModeSwitcher()),
      ],
    );
  }
}
