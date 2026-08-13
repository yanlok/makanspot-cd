import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/controllers/auth_state.dart';

class MakanSpotApp extends ConsumerStatefulWidget {
  const MakanSpotApp({this.router, super.key});

  final GoRouter? router;

  @override
  ConsumerState<MakanSpotApp> createState() => _MakanSpotAppState();
}

class _MakanSpotAppState extends ConsumerState<MakanSpotApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = widget.router ?? createAppRouter(ref: ref);
    // Restore the saved session (if any) so a logged-in user lands on the
    // dashboard after a restart; the router redirect follows the state.
    ref.read(authControllerProvider.notifier).restoreSession();
  }

  @override
  void dispose() {
    if (widget.router == null) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-run the router redirect whenever the auth state changes (login,
    // logout, session restore), so navigation follows the session.
    ref.listen<AuthState>(authControllerProvider, (_, _) => _router.refresh());
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MakanSpot',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
