import 'package:flutter/foundation.dart';

/// An authenticated session for a user or admin account.
@immutable
class AuthSession {
  const AuthSession({
    this.id,
    required this.email,
    this.username,
    required this.role,
  });

  static const roleUser = 'user';
  static const roleAdmin = 'admin';

  /// Backend user id; null in fixture mode.
  final String? id;

  final String email;

  /// Display name from the profile; null when unknown.
  final String? username;

  /// Account role: [roleUser] or [roleAdmin].
  final String role;

  bool get isAdmin => role == roleAdmin;
}
