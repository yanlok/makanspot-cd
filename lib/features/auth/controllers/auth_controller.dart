import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:makanspot/core/config/supabase_config.dart';

import '../models/auth_repository.dart';
import '../models/fixture_auth_repository.dart';
import '../models/supabase_auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository();
  }
  return FixtureAuthRepository();
});

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AuthState>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<bool> login(String rawEmail, String rawPassword) async {
    final email = rawEmail.trim();
    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(rawPassword);
    state = state.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      errorMessage: null,
    );
    if (emailError != null || passwordError != null) {
      return false;
    }
    return _run(() => _repository.login(email: email, password: rawPassword));
  }

  Future<bool> register({
    required String rawEmail,
    required String rawPassword,
    required String confirmPassword,
  }) async {
    final email = rawEmail.trim();
    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(rawPassword);
    final String? confirmPasswordError;
    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Confirm your password.';
    } else if (rawPassword != confirmPassword) {
      confirmPasswordError = 'Passwords do not match.';
    } else {
      confirmPasswordError = null;
    }
    state = state.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      confirmPasswordError: confirmPasswordError,
      errorMessage: null,
    );
    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      return false;
    }
    final succeeded = await _run(
      () => _repository.register(email: email, password: rawPassword),
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

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email is required.';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
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
    final emailError = _validateEmail(email);
    state = state.copyWith(emailError: emailError, errorMessage: null);
    if (emailError != null) {
      return;
    }
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.requestPasswordReset(email);
    } on AuthFailure catch (failure) {
      _showError(failure.message);
      return;
    } on Object {
      _showError('Something went wrong. Please try again.');
      return;
    }
    state = state.copyWith(status: AuthStatus.success, passwordResetSent: true);
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    final passwordError = _validatePassword(password);
    final String? confirmPasswordError;
    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Confirm your new password.';
    } else if (password != confirmPassword) {
      confirmPasswordError = 'Passwords do not match.';
    } else {
      confirmPasswordError = null;
    }
    state = state.copyWith(
      passwordError: passwordError,
      confirmPasswordError: confirmPasswordError,
      errorMessage: null,
    );
    if (passwordError != null || confirmPasswordError != null) {
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
      state = state.copyWith(
        status: AuthStatus.success,
        emailError: null,
        passwordError: null,
        confirmPasswordError: null,
      );
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
