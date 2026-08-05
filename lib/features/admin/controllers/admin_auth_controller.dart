import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/core/config/supabase_config.dart';

class AdminAuthState {
  const AdminAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  AdminAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AdminAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Kept alive so the administrator session survives route changes.
final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AdminAuthState>((ref) {
      return AdminAuthController();
    });

class AdminAuthController extends StateNotifier<AdminAuthState> {
  AdminAuthController() : super(const AdminAuthState());

  /// Demo credentials used only when the Supabase backend is not
  /// configured (fixture mode). With a backend, sign-in goes through
  /// Supabase auth instead.
  static const demoEmail = 'admin@makanspot.my';
  static const demoPassword = 'admin123';

  Future<bool> login(String rawEmail, String rawPassword) async {
    final email = rawEmail.trim();
    if (email.isEmpty || rawPassword.isEmpty) {
      state = state.copyWith(errorMessage: 'Enter your email and password.');
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    // Temporary diagnostics while investigating slow admin login.
    debugPrint(
      'AdminLogin: start for $email (supabase configured: '
      '${SupabaseConfig.isConfigured})',
    );
    final stopwatch = Stopwatch()..start();
    try {
      if (SupabaseConfig.isConfigured) {
        await _signInWithSupabase(email, rawPassword);
      } else if (email.toLowerCase() != demoEmail ||
          rawPassword != demoPassword) {
        throw AuthException(
          'Invalid administrator credentials. Check the demo credentials '
          'and try again.',
        );
      }
      debugPrint(
        'AdminLogin: authenticated after ${stopwatch.elapsedMilliseconds} ms',
      );
      state = state.copyWith(isAuthenticated: true, isLoading: false);
      return true;
    } on TimeoutException {
      debugPrint(
        'AdminLogin: timed out after ${stopwatch.elapsedMilliseconds} ms',
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Sign-in timed out. Check your internet connection and that '
            'the Supabase project is running.',
      );
    } on AuthException catch (error) {
      debugPrint(
        'AdminLogin: AuthException after ${stopwatch.elapsedMilliseconds} '
        'ms: ${error.message}',
      );
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on Object catch (error) {
      debugPrint(
        'AdminLogin: unexpected error after ${stopwatch.elapsedMilliseconds} '
        'ms: $error',
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not sign in right now. Please try again.',
      );
    }
    return false;
  }

  void logout() {
    state = const AdminAuthState();
    if (SupabaseConfig.isConfigured) {
      unawaited(_signOutIgnoringErrors());
    }
  }

  /// Temporary demo shortcut used by the prototype mode switcher to leave the
  /// console.
  void exitDemoSession() {
    state = const AdminAuthState();
  }

  Future<void> _signInWithSupabase(String email, String password) async {
    final client = Supabase.instance.client;
    // Temporary diagnostics while investigating slow admin login.
    debugPrint('AdminLogin: calling auth.signInWithPassword...');
    await client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));
    debugPrint('AdminLogin: signInWithPassword OK');

    final user = client.auth.currentUser;
    debugPrint('AdminLogin: currentUser = ${user?.id ?? 'null'}');
    final row = user == null
        ? null
        : await client
              .from('users')
              .select('role')
              .eq('id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));
    debugPrint('AdminLogin: role row = ${row == null ? 'null' : row['role']}');
    if (row == null || row['role'] != 'admin') {
      // Do not leave a non-admin session behind.
      await client.auth.signOut();
      throw AuthException('This account does not have administrator access.');
    }
  }

  Future<void> _signOutIgnoringErrors() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } on Object {
      // The next login replaces any leftover session.
    }
  }
}
