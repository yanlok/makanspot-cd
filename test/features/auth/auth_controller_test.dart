import 'package:flutter_test/flutter_test.dart';

import 'package:makanspot/features/auth/controllers/auth_controller.dart';
import 'package:makanspot/features/auth/controllers/auth_state.dart';
import 'package:makanspot/features/auth/models/fixture_auth_repository.dart';

void main() {
  late AuthController controller;

  setUp(() {
    controller = AuthController(FixtureAuthRepository());
  });

  tearDown(() {
    controller.dispose();
  });

  group('login', () {
    test('rejects empty email and password with field errors', () async {
      final succeeded = await controller.login('', '');

      expect(succeeded, isFalse);
      expect(controller.state.emailError, 'Email is required.');
      expect(controller.state.passwordError, 'Password is required.');
    });

    test('rejects an invalid email format', () async {
      final succeeded = await controller.login('not-an-email', 'secret12');

      expect(succeeded, isFalse);
      expect(controller.state.emailError, 'Enter a valid email address.');
    });

    test('authenticates valid demo credentials', () async {
      final succeeded = await controller.login(
        FixtureAuthRepository.demoEmail,
        FixtureAuthRepository.demoPassword,
      );

      expect(succeeded, isTrue);
      expect(controller.state.status, AuthStatus.success);
    });

    test('displays an error message for invalid credentials', () async {
      final succeeded = await controller.login(
        'user@makanspot.my',
        'wrong-password',
      );

      expect(succeeded, isFalse);
      expect(controller.state.status, AuthStatus.error);
      expect(
        controller.state.errorMessage,
        contains('Invalid email or password'),
      );
    });
  });

  group('register', () {
    test('rejects missing fields with field errors', () async {
      final succeeded = await controller.register(
        rawEmail: '',
        rawPassword: '',
        confirmPassword: '',
      );

      expect(succeeded, isFalse);
      expect(controller.state.emailError, 'Email is required.');
      expect(controller.state.passwordError, 'Password is required.');
      expect(controller.state.confirmPasswordError, 'Confirm your password.');
    });

    test('rejects mismatched passwords', () async {
      final succeeded = await controller.register(
        rawEmail: 'user@example.com',
        rawPassword: 'secret12',
        confirmPassword: 'different12',
      );

      expect(succeeded, isFalse);
      expect(
        controller.state.confirmPasswordError,
        'Passwords do not match.',
      );
    });

    test('registers a new account and moves to OTP verification', () async {
      final succeeded = await controller.register(
        rawEmail: 'new@example.com',
        rawPassword: 'secret12',
        confirmPassword: 'secret12',
      );

      expect(succeeded, isTrue);
      expect(controller.state.awaitingOtp, isTrue);
      expect(controller.state.registrationEmail, 'new@example.com');
    });

    test('prevents registering with an email that already exists', () async {
      final repository = FixtureAuthRepository();
      final first = AuthController(repository);
      await first.register(
        rawEmail: 'taken@example.com',
        rawPassword: 'secret12',
        confirmPassword: 'secret12',
      );

      final second = AuthController(repository);
      final succeeded = await second.register(
        rawEmail: 'taken@example.com',
        rawPassword: 'secret12',
        confirmPassword: 'secret12',
      );

      expect(succeeded, isFalse);
      expect(second.state.status, AuthStatus.error);
      expect(second.state.errorMessage, contains('already exists'));
      first.dispose();
      second.dispose();
    });
  });
}
