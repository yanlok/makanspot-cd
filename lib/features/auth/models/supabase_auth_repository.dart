import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

/// Supabase-backed implementation of [AuthRepository].
///
/// Requires `Supabase.initialize` to have run (see `main.dart`). Session
/// persistence and restoration are handled by `supabase_flutter` itself.
class SupabaseAuthRepository implements AuthRepository {
  @override
  Future<void> login({required String email, required String password}) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      // With email confirmation enabled (Supabase default) this returns a user
      // whose email is unconfirmed; the OTP screen then calls [verifyOtp].
      await Supabase.instance.client.auth.signUp(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: code,
        email: email,
      );
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> resendOtp(String email) async {
    try {
      await Supabase.instance.client.auth.resend(type: OtpType.email, email: email);
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      // The reset email link authenticates the session; updating the password
      // is then done against the current (confirmed) user.
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }
}

/// Translates a Supabase [AuthException] into a user-facing message.
///
/// Kept as a pure top-level function so it can be unit tested without a live
/// backend. Unknown errors fall back to a generic message instead of leaking
/// raw exception text.
String authErrorMessage(AuthException error) {
  final code = error.code;
  final message = error.message.toLowerCase();
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return 'Invalid email or password.';
  }
  if (code == 'email_not_confirmed') {
    return 'Please verify your email before logging in.';
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      message.contains('already registered') ||
      message.contains('already been registered')) {
    return 'An account with this email already exists.';
  }
  return 'Authentication failed. Please try again.';
}