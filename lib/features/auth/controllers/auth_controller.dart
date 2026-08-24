import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:makanspot/core/config/supabase_config.dart';

import '../models/auth_repository.dart';
import '../models/fixture_auth_repository.dart';
import '../models/supabase_auth_repository.dart';
import 'auth_state.dart';
import 'auth_validators.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository();
  }
  return FixtureAuthRepository();
});

/// Kept alive so the session survives route changes and can gate the router.
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository)
    : super(const AuthState(status: AuthStatus.restoring));

  final AuthRepository _repository;

  /// Restores the saved session on startup; called once from the app root.
  Future<void> restoreSession() async {
    try {
      final session = await _repository.restoreSession();
      state = session == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, session: session);
    } on Object {
      // A failed restore is treated as signed out so the app never gets
      // stuck mid-startup.
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String rawEmail, String rawPassword) async {
    final email = rawEmail.trim();
    final emailError = validateEmail(email);
    final passwordError = validatePassword(rawPassword);
    state = state.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      errorMessage: null,
      registrationSucceeded: false,
    );
    if (emailError != null || passwordError != null) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final session = await _repository.login(
        email: email,
        password: rawPassword,
      );
      state = AuthState(status: AuthStatus.authenticated, session: session);
      return true;
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
    return false;
  }

  Future<bool> register({
    required String rawEmail,
    required String rawPassword,
    required String confirmPassword,
  }) async {
    final email = rawEmail.trim();
    final emailError = validateEmail(email);
    final passwordError = validatePassword(rawPassword);
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
      registrationSucceeded: false,
    );
    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final session = await _repository.register(
        email: email,
        password: rawPassword,
      );
      if (session == null) {
        // The account was created but cannot be used yet (for example email
        // confirmation is pending); the user signs in on the Login screen.
        state = state.copyWith(
          isSubmitting: false,
          registrationSucceeded: true,
        );
      } else {
        state = AuthState(status: AuthStatus.authenticated, session: session);
      }
      return true;
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
    return false;
  }

  /// Signs out and clears the saved session. The router redirect sends the
  /// user to the Login screen.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } on Object {
      // The local session is cleared anyway; a failed remote sign-out is
      // replaced by the next sign-in.
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Permanently deletes the signed-in user's account and signs out.
  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> deleteAccount() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.deleteAccount();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return null;
    } on AuthFailure catch (failure) {
      _showError(failure.message);
      return failure.message;
    } on Object {
      _showError('Something went wrong. Please try again.');
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> requestPasswordReset(String rawEmail) async {
    final email = rawEmail.trim();
    final emailError = validateEmail(email);
    state = state.copyWith(emailError: emailError, errorMessage: null);
    if (emailError != null) {
      return;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.requestPasswordReset(email);
    } on AuthFailure catch (failure) {
      _showError(failure.message);
      return;
    } on Object {
      _showError('Something went wrong. Please try again.');
      return;
    }
    state = state.copyWith(isSubmitting: false, passwordResetSent: true);
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    final passwordError = validatePassword(password);
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
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.resetPassword(token: token, newPassword: password);
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        passwordResetSucceeded: true,
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
    state = state.copyWith(isSubmitting: false, errorMessage: message);
  }
}
