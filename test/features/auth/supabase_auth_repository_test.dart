import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/features/auth/models/supabase_auth_repository.dart';

void main() {
  group('authErrorMessage', () {
    test('maps invalid login credentials', () {
      final error = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(
        authErrorMessage(error),
        'Invalid email or password.',
      );
    });

    test('maps duplicate email registration by code', () {
      final error = AuthException(
        'User already registered',
        code: 'user_already_exists',
      );
      expect(
        authErrorMessage(error),
        'An account with this email already exists.',
      );
    });

    test('maps duplicate email registration by message', () {
      final error = AuthException('A user with this email has already been registered');
      expect(
        authErrorMessage(error),
        'An account with this email already exists.',
      );
    });

    test('maps unconfirmed email', () {
      final error = AuthException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      );
      expect(
        authErrorMessage(error),
        'Please verify your email before logging in.',
      );
    });

    test('falls back to a generic message for unknown errors', () {
      final error = AuthException('rate limit exceeded');
      expect(
        authErrorMessage(error),
        'Authentication failed. Please try again.',
      );
    });
  });
}
