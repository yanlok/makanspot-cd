import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_repository.dart';
import 'auth_controller.dart';
import 'auth_validators.dart';

final changePasswordControllerProvider =
    StateNotifierProvider.autoDispose<
      ChangePasswordController,
      ChangePasswordState
    >((ref) => ChangePasswordController(ref.watch(authRepositoryProvider)));

@immutable
class ChangePasswordState {
  const ChangePasswordState({
    this.isSubmitting = false,
    this.currentPasswordError,
    this.newPasswordError,
    this.confirmPasswordError,
    this.errorMessage,
    this.succeeded = false,
  });

  final bool isSubmitting;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? confirmPasswordError;
  final String? errorMessage;
  final bool succeeded;

  ChangePasswordState copyWith({
    bool? isSubmitting,
    String? currentPasswordError,
    String? newPasswordError,
    String? confirmPasswordError,
    String? errorMessage,
    bool? succeeded,
  }) {
    return ChangePasswordState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      currentPasswordError: currentPasswordError,
      newPasswordError: newPasswordError,
      confirmPasswordError: confirmPasswordError,
      errorMessage: errorMessage,
      succeeded: succeeded ?? this.succeeded,
    );
  }
}

class ChangePasswordController extends StateNotifier<ChangePasswordState> {
  ChangePasswordController(this._repository)
    : super(const ChangePasswordState());

  final AuthRepository _repository;

  Future<bool> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final currentPasswordError = currentPassword.isEmpty
        ? 'Enter your current password.'
        : null;
    final newPasswordError = validatePassword(newPassword);
    final String? confirmPasswordError;
    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Confirm your new password.';
    } else if (newPassword != confirmPassword) {
      confirmPasswordError = 'Passwords do not match.';
    } else {
      confirmPasswordError = null;
    }
    state = state.copyWith(
      currentPasswordError: currentPasswordError,
      newPasswordError: newPasswordError,
      confirmPasswordError: confirmPasswordError,
      errorMessage: null,
      succeeded: false,
    );
    if (currentPasswordError != null ||
        newPasswordError != null ||
        confirmPasswordError != null) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.changePassword(
        email: email,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isSubmitting: false, succeeded: true);
      return true;
    } on AuthFailure catch (failure) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      );
    } on Object {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
    return false;
  }
}
