import 'package:flutter/foundation.dart';

enum AuthStatus { idle, loading, success, error }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.registrationEmail,
    this.awaitingOtp = false,
    this.passwordResetSent = false,
    this.resendConfirmation,
  });

  final AuthStatus status;
  final String? errorMessage;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final String? registrationEmail;
  final bool awaitingOtp;
  final bool passwordResetSent;
  final String? resendConfirmation;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? emailError,
    String? passwordError,
    String? confirmPasswordError,
    String? registrationEmail,
    bool? awaitingOtp,
    bool? passwordResetSent,
    String? resendConfirmation,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      emailError: emailError,
      passwordError: passwordError,
      confirmPasswordError: confirmPasswordError,
      registrationEmail: registrationEmail ?? this.registrationEmail,
      awaitingOtp: awaitingOtp ?? this.awaitingOtp,
      passwordResetSent: passwordResetSent ?? this.passwordResetSent,
      resendConfirmation: resendConfirmation,
    );
  }
}
