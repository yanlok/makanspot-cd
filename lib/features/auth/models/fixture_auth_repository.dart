import 'auth_repository.dart';

class FixtureAuthRepository implements AuthRepository {
  const FixtureAuthRepository();

  static const demoEmail = 'user@makanspot.my';
  static const demoPassword = 'user123';

  @override
  Future<void> login({required String email, required String password}) async {
    if (email.toLowerCase() != demoEmail || password != demoPassword) {
      throw const AuthFailure(
        'Invalid user credentials. Check the demo credentials and try again.',
      );
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {}

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
}
