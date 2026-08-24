import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:makanspot/core/constants/demo_accounts.dart';

import 'auth_repository.dart';
import 'auth_session.dart';

/// In-memory credential store backing the auth screens when the Supabase
/// backend is not configured.
///
/// Seeds the demo accounts so the app is usable without first creating an
/// account, while still supporting real registration flow (including
/// duplicate-email rejection). The signed-in session is persisted with
/// [SharedPreferences] so a restart keeps the user logged in, mirroring
/// `supabase_flutter` behaviour in backend mode. Account credentials stay in
/// memory, so a registered or changed password is not restored after a
/// restart.
class FixtureAuthRepository implements AuthRepository {
  FixtureAuthRepository({Map<String, FixtureAccount>? accounts})
    : _accounts = Map.of(accounts ?? const {}) {
    _accounts.putIfAbsent(
      DemoAccounts.userEmail,
      () => FixtureAccount(
        password: DemoAccounts.userPassword,
        role: AuthSession.roleUser,
      ),
    );
    _accounts.putIfAbsent(
      DemoAccounts.adminEmail,
      () => FixtureAccount(
        password: DemoAccounts.adminPassword,
        role: AuthSession.roleAdmin,
      ),
    );
  }

  static const _sessionKey = 'fixture_auth_session';

  final Map<String, FixtureAccount> _accounts;
  final Map<String, String> _resetTokensByEmail = {};

  /// Test seam: the reset token issued for [email], if one is pending.
  String? resetTokenFor(String email) => _resetTokensByEmail[_normalize(email)];

  @override
  Future<AuthSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession(
        email: json['email'] as String,
        role: json['role'] as String,
      );
    } on Object {
      // A corrupted or stale session is treated as signed out.
      return null;
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalize(email);
    final account = _accounts[normalizedEmail];
    if (account == null || account.password != password) {
      throw const AuthFailure('Invalid email or password.');
    }
    final session = AuthSession(email: normalizedEmail, role: account.role);
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession?> register({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalize(email);
    if (_accounts.containsKey(normalizedEmail)) {
      throw const AuthFailure('An account with this email already exists.');
    }
    _accounts[normalizedEmail] = FixtureAccount(
      password: password,
      role: AuthSession.roleUser,
    );
    // Fixture accounts are usable immediately, so registration returns a
    // session and the user is signed in (auto-login).
    final session = AuthSession(
      email: normalizedEmail,
      role: AuthSession.roleUser,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final normalizedEmail = _normalize(email);
    if (!_accounts.containsKey(normalizedEmail)) {
      throw const AuthFailure('No account found with this email address.');
    }
    final random = Random();
    final token = List.generate(
      6,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    _resetTokensByEmail[normalizedEmail] = token;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    String? email;
    for (final entry in _resetTokensByEmail.entries) {
      if (entry.value == token) {
        email = entry.key;
        break;
      }
    }
    if (email == null) {
      throw const AuthFailure('This reset link is invalid or has expired.');
    }
    final current = _accounts[email]!;
    _accounts[email] = FixtureAccount(
      password: newPassword,
      role: current.role,
    );
    _resetTokensByEmail.remove(email);
  }

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final normalizedEmail = _normalize(email);
    final account = _accounts[normalizedEmail];
    if (account == null || account.password != currentPassword) {
      throw const AuthFailure('Your current password is incorrect.');
    }
    _accounts[normalizedEmail] = FixtureAccount(
      password: newPassword,
      role: account.role,
    );
  }

  @override
  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) {
      throw const AuthFailure('No signed-in account to delete.');
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final email = _normalize(json['email'] as String);
    _accounts.remove(email);
    _resetTokensByEmail.remove(email);
    await prefs.remove(_sessionKey);
  }

  Future<void> _persist(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({'email': session.email, 'role': session.role}),
    );
  }

  String _normalize(String email) => email.trim().toLowerCase();
}

class FixtureAccount {
  const FixtureAccount({required this.password, required this.role});

  final String password;
  final String role;
}
