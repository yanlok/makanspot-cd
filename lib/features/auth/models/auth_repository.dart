import 'auth_session.dart';

/// Backend-agnostic access to authentication and password management.
abstract interface class AuthRepository {
  /// Restores the persisted session, or null when no session is saved.
  Future<AuthSession?> restoreSession();

  /// Signs in and returns the session with the account role.
  Future<AuthSession> login({required String email, required String password});

  /// Creates an account. Returns a session when the account can be used
  /// immediately; returns null when sign-in still requires a backend action
  /// (for example email confirmation).
  Future<AuthSession?> register({
    required String email,
    required String password,
  });

  /// Ends the current session.
  Future<void> logout();

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  });
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
