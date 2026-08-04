import 'package:flutter_test/flutter_test.dart';

import 'package:makanspot/features/auth/models/auth_repository.dart';
import 'package:makanspot/features/auth/models/fixture_auth_repository.dart';

void main() {
  group('FixtureAuthRepository', () {
    test('logs in with the seeded demo credentials', () async {
      final repository = FixtureAuthRepository();
      await expectLater(
        repository.login(
          email: FixtureAuthRepository.demoEmail,
          password: FixtureAuthRepository.demoPassword,
        ),
        completes,
      );
    });

    test('rejects login with wrong password', () async {
      final repository = FixtureAuthRepository();
      await expectLater(
        repository.login(
          email: FixtureAuthRepository.demoEmail,
          password: 'wrong-password',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Invalid email or password'),
          ),
        ),
      );
    });

    test('rejects login for an unregistered email', () async {
      final repository = FixtureAuthRepository();
      await expectLater(
        repository.login(email: 'nobody@example.com', password: 'secret12'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('registers a new account and logs in with it', () async {
      final repository = FixtureAuthRepository();
      await repository.register(
        email: 'new@example.com',
        password: 'secret12',
      );
      await expectLater(
        repository.login(email: 'new@example.com', password: 'secret12'),
        completes,
      );
    });

    test('prevent duplicate email registration case-insensitively', () async {
      final repository = FixtureAuthRepository();
      await repository.register(
        email: 'user@example.com',
        password: 'secret12',
      );
      await expectLater(
        repository.register(
          email: 'USER@Example.com',
          password: 'another12',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });
  });
}
