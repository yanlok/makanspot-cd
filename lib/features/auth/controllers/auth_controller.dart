import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_repository.dart';
import '../models/fixture_auth_repository.dart';
import '../models/supabase_auth_repository.dart';
import 'package:makanspot/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return const FixtureAuthRepository();
});

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AuthState>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<bool> login(String rawEmail, String password) async {
    final email = rawEmail.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Enter your email and password.');
      return false;
    }
    return _run(() => _repository.login(email: email, password: password));
  }

  Future<bool> register({
    required String rawEmail,
    required String password,
    required String confirmPassword,
  }) async {
    final email = rawEmail.trim();
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Complete all fields.');
      return false;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return false;
    }
    final succeeded = await _run(
      () => _repository.register(email: email, password: password),
    );
    if (succeeded) {
      state = state.copyWith(
        status: AuthStatus.idle,
        registrationEmail: email,
        awaitingOtp: true,
      );
    }
    return succeeded;
  }

  Future<bool> verifyOtp(String code) async {
    final email = state.registrationEmail;
    if (email == null || code.length != 6) {
      _showError('Enter the 6-digit verification code.');
      return false;
    }
    return _run(() => _repository.verifyOtp(email: email, code: code));
  }

  Future<void> resendOtp() async {
    final email = state.registrationEmail;
    if (email == null) {
      return;
    }
    try {
      await _repository.resendOtp(email);
      state = state.copyWith(
        status: AuthStatus.idle,
        resendConfirmation: 'Check your email for the new code.',
      );
    } on Object {
      _showError('Failed to resend code');
    }
  }

  Future<void> requestPasswordReset(String rawEmail) async {
    final email = rawEmail.trim();
    if (email.isEmpty) {
      _showError('Enter your email address.');
      return;
    }
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.requestPasswordReset(email);
    } on Object {
      // Account discovery is intentionally prevented by showing one result.
    }
    state = state.copyWith(status: AuthStatus.success, passwordResetSent: true);
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    if (password.isEmpty || confirmPassword.isEmpty) {
      _showError('Complete all fields.');
      return false;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return false;
    }
    return _run(
      () => _repository.resetPassword(token: token, newPassword: password),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await action();
      state = state.copyWith(status: AuthStatus.success);
      return true;
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
    return false;
  }

  void _showError(String message) {
    state = state.copyWith(status: AuthStatus.error, errorMessage: message);
  }
}
