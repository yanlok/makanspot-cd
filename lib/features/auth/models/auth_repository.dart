abstract interface class AuthRepository {
  Future<void> login({required String email, required String password});

  Future<void> register({required String email, required String password});

  Future<void> verifyOtp({required String email, required String code});

  Future<void> resendOtp(String email);

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
