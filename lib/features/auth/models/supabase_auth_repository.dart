import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'auth_session.dart';

/// Supabase-backed implementation of [AuthRepository].
///
/// Requires `Supabase.initialize` to have run (see `main.dart`); session
/// persistence and restoration are handled by `supabase_flutter` itself.
class SupabaseAuthRepository implements AuthRepository {
  @override
  Future<AuthSession?> restoreSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return null;
    }
    return _sessionForUser(session.user);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Authentication failed. Please try again.');
      }
      return await _sessionForUser(user);
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<AuthSession?> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      // When email confirmation is enabled, signUp returns a user but no
      // session — the user must confirm their email before signing in.
      if (response.session == null) {
        return null;
      }
      final user = response.user;
      if (user == null) {
        return null;
      }
      return await _sessionForUser(user);
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();
      if (profile == null) {
        throw const AuthFailure('No account found with this email address.');
      }
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.example.makanspot://reset-password',
      );
    } on AuthException catch (error) {
      // ignore: avoid_print
      print('[PasswordReset] AuthException: ${error.message} (code: ${error.code})');
      throw AuthFailure(authErrorMessage(error));
    } on Exception catch (error) {
      // ignore: avoid_print
      print('[PasswordReset] Exception: $error');
      throw AuthFailure('Password reset failed: ${error.toString()}');
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      // The Supabase SDK exchanges the code from the deep link for a session
      // automatically. updateUser works against that session.
      final session = Supabase.instance.client.auth.currentSession;
      // ignore: avoid_print
      print('[PasswordReset] session=${session != null} user=${Supabase.instance.client.auth.currentUser?.id}');
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      // Sign out after reset so the user logs in with the new password.
      await Supabase.instance.client.auth.signOut();
    } on AuthException catch (error) {
      // ignore: avoid_print
      print('[PasswordReset] AuthException: ${error.message} (code: ${error.code})');
      throw AuthFailure(authErrorMessage(error));
    } on Exception catch (error) {
      // ignore: avoid_print
      print('[PasswordReset] Exception: $error');
      throw AuthFailure('Password reset failed: ${error.toString()}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthFailure('No signed-in account to delete.');
      }
      // Call a server-side function that cleans up public data then deletes
      // the auth user (which requires elevated privileges).
      await Supabase.instance.client.rpc('delete_current_user');
    } on AuthException catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Re-authenticate with the current password before updating, so a wrong
      // current password is rejected by the backend.
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (error) {
      if (error.code == 'invalid_credentials' ||
          error.message.toLowerCase().contains('invalid login credentials')) {
        throw const AuthFailure('Your current password is incorrect.');
      }
      throw AuthFailure(authErrorMessage(error));
    }
  }

  /// Builds the session for a signed-in [user], reading the account role from
  /// `public.users` (auto-created for every auth user on signup).
  Future<AuthSession> _sessionForUser(User user) async {
    final row = await Supabase.instance.client
        .from('users')
        .select('role, username')
        .eq('id', user.id)
        .maybeSingle();
    return AuthSession(
      id: user.id,
      email: user.email ?? '',
      username: row?['username'] as String?,
      role: (row?['role'] as String?) ?? AuthSession.roleUser,
    );
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
  if (code == 'same_password') {
    return 'New password must be different from your current password.';
  }
  return 'Authentication failed. Please try again.';
}
