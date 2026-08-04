import 'auth_repository.dart';

/// In-memory credential store backing the auth screens.
///
/// Keeps the demo account registered so the app is usable without first
/// creating an account, while still supporting real registration flow
/// (including duplicate-email rejection) for the lifetime of the process.
class FixtureAuthRepository implements AuthRepository {
  FixtureAuthRepository({Map<String, String>? credentials})
      : _credentials = Map.of(credentials ?? const {}) {
    _credentials.putIfAbsent(demoEmail, () => demoPassword);
  }

  static const demoEmail = 'user@makanspot.my';
  static const demoPassword = 'user123';

  final Map<String, String> _credentials;

  @override
  Future<void> login({required String email, required String password}) async {
    final storedPassword = _credentials[_normalize(email)];
    if (storedPassword == null || storedPassword != password) {
      throw const AuthFailure('Invalid email or password.');
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalize(email);
    if (_credentials.containsKey(normalizedEmail)) {
      throw const AuthFailure(
        'An account with this email already exists.',
      );
    }
    _credentials[normalizedEmail] = password;
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    if (code != '123456') {
      throw const AuthFailure('Invalid verification code');
    }
  }

  @override
  Future<void> resendOtp(String email) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  String _normalize(String email) => email.trim().toLowerCase();
}
