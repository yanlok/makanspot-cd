import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> login({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': email.split('@').first},
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.signup,
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> resendOtp(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _client.auth.verifyOTP(tokenHash: token, type: OtpType.recovery);
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
