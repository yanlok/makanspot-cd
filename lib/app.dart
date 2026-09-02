import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

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
  StreamSubscription<supa.AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _router = widget.router ?? createAppRouter(ref: ref);
    ref.read(authControllerProvider.notifier).restoreSession();

    // Let the Supabase SDK handle the deep link internally (it exchanges the
    // auth code for a session). Listen for auth state changes to navigate
    // after the SDK processes the reset link.
    _authSub = supa.Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      // ignore: avoid_print
      print('[Auth] event=${data.event} session=${data.session != null}');
      if (data.event == supa.AuthChangeEvent.passwordRecovery) {
        if (mounted) _router.go('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    if (widget.router == null) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      _router.refresh();
    });
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MakanSpot',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
