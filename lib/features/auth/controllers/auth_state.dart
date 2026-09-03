import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';

enum AuthStatus { restoring, unauthenticated, authenticated }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.session,
    this.isSubmitting = false,
    this.errorMessage,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.passwordResetSent = false,
    this.passwordResetSucceeded = false,
    this.registrationSucceeded = false,
  });

  /// Overall session status.
  final AuthStatus status;

  /// The signed-in session; non-null when [status] is
  /// [AuthStatus.authenticated].
  final AuthSession? session;

  /// Whether a form submission is in progress.
  final bool isSubmitting;

  /// General authentication error (for example invalid credentials).
  final String? errorMessage;

  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;

  /// Set after a successful forgot-password request.
  final bool passwordResetSent;

  /// Set after a successful password reset (user should re-login).
  final bool passwordResetSucceeded;

  /// Set after registration when the account must be signed into manually
  /// (no session was returned by the backend).
  final bool registrationSucceeded;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    bool? isSubmitting,
    String? errorMessage,
    String? emailError,
    String? passwordError,
    String? confirmPasswordError,
    bool? passwordResetSent,
    bool? passwordResetSucceeded,
    bool? registrationSucceeded,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      emailError: emailError,
      passwordError: passwordError,
      confirmPasswordError: confirmPasswordError,
      passwordResetSent: passwordResetSent ?? this.passwordResetSent,
      passwordResetSucceeded:
          passwordResetSucceeded ?? this.passwordResetSucceeded,
      registrationSucceeded:
          registrationSucceeded ?? this.registrationSucceeded,
    );
  }
}
