import 'package:flutter_test/flutter_test.dart';

import 'package:makanspot/features/auth/controllers/auth_controller.dart';
import 'package:makanspot/features/auth/controllers/auth_state.dart';
import 'package:makanspot/features/auth/models/auth_repository.dart';
import 'package:makanspot/features/auth/models/fixture_auth_repository.dart';

void main() {
  group('FixtureAuthRepository password recovery', () {
    test('rejects reset request for an unregistered email', () async {
      final repository = FixtureAuthRepository();
      await expectLater(
        repository.requestPasswordReset('nobody@example.com'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            contains('No account found'),
          ),
        ),
      );
    });

    test('issues a reset token for a registered email', () async {
      final repository = FixtureAuthRepository();
      await repository.requestPasswordReset(FixtureAuthRepository.demoEmail);

      expect(repository.resetTokenFor(FixtureAuthRepository.demoEmail),
          isNotNull);
    });

    test('rejects reset with an invalid token', () async {
      final repository = FixtureAuthRepository();
      await repository.requestPasswordReset(FixtureAuthRepository.demoEmail);

      await expectLater(
        repository.resetPassword(token: 'bad-token', newPassword: 'newpass12'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            contains('invalid or has expired'),
          ),
        ),
      );
    });

    test('updates the password when the token is valid', () async {
      final repository = FixtureAuthRepository();
      await repository.requestPasswordReset(FixtureAuthRepository.demoEmail);
      final token = repository.resetTokenFor(FixtureAuthRepository.demoEmail)!;

      await repository.resetPassword(token: token, newPassword: 'newpass12');

      await expectLater(
        repository.login(
          email: FixtureAuthRepository.demoEmail,
          password: 'newpass12',
        ),
        completes,
      );
      await expectLater(
        repository.login(
          email: FixtureAuthRepository.demoEmail,
          password: FixtureAuthRepository.demoPassword,
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('invalidates the token after use', () async {
      final repository = FixtureAuthRepository();
      await repository.requestPasswordReset(FixtureAuthRepository.demoEmail);
      final token = repository.resetTokenFor(FixtureAuthRepository.demoEmail)!;
      await repository.resetPassword(token: token, newPassword: 'newpass12');

      await expectLater(
        repository.resetPassword(token: token, newPassword: 'again12'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('AuthController password recovery', () {
    late AuthController controller;
    late FixtureAuthRepository repository;

    setUp(() {
      repository = FixtureAuthRepository();
      controller = AuthController(repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('rejects forgot-password for an invalid email format', () async {
      await controller.requestPasswordReset('not-an-email');

      expect(controller.state.passwordResetSent, isFalse);
      expect(controller.state.emailError, 'Enter a valid email address.');
    });

    test('shows an error for an unregistered email', () async {
      await controller.requestPasswordReset('nobody@example.com');

      expect(controller.state.passwordResetSent, isFalse);
      expect(controller.state.status, AuthStatus.error);
      expect(
        controller.state.errorMessage,
        contains('No account found'),
      );
    });

    test('confirms when the reset request succeeds', () async {
      await controller.requestPasswordReset(FixtureAuthRepository.demoEmail);

      expect(controller.state.passwordResetSent, isTrue);
      expect(repository.resetTokenFor(FixtureAuthRepository.demoEmail),
          isNotNull);
    });

    test('rejects a new password shorter than 6 characters', () async {
      final succeeded = await controller.resetPassword(
        token: 'anything',
        password: '123',
        confirmPassword: '123',
      );

      expect(succeeded, isFalse);
      expect(
        controller.state.passwordError,
        'Password must be at least 6 characters.',
      );
    });

    test('rejects mismatched new passwords', () async {
      final succeeded = await controller.resetPassword(
        token: 'anything',
        password: 'newpass12',
        confirmPassword: 'different12',
      );

      expect(succeeded, isFalse);
      expect(
        controller.state.confirmPasswordError,
        'Passwords do not match.',
      );
    });

    test('updates the password and signs in with the new one', () async {
      await repository.requestPasswordReset(FixtureAuthRepository.demoEmail);
      final token = repository.resetTokenFor(FixtureAuthRepository.demoEmail)!;

      final succeeded = await controller.resetPassword(
        token: token,
        password: 'newpass12',
        confirmPassword: 'newpass12',
      );

      expect(succeeded, isTrue);
      await expectLater(
        repository.login(
          email: FixtureAuthRepository.demoEmail,
          password: 'newpass12',
        ),
        completes,
      );
    });
  });
}