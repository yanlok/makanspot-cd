import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminAuthState {
  const AdminAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  AdminAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AdminAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Kept alive so the administrator session survives route changes.
final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AdminAuthState>((ref) {
      return AdminAuthController();
    });

class AdminAuthController extends StateNotifier<AdminAuthState> {
  AdminAuthController() : super(const AdminAuthState());

  static const demoEmail = 'admin@makanspot.my';
  static const demoPassword = 'admin123';

  Future<bool> login(String rawEmail, String rawPassword) async {
    final email = rawEmail.trim();
    if (email.isEmpty || rawPassword.isEmpty) {
      state = state.copyWith(errorMessage: 'Enter your email and password.');
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (email.toLowerCase() != demoEmail || rawPassword != demoPassword) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Invalid administrator credentials. Check the demo credentials '
            'and try again.',
      );
      return false;
    }
    state = state.copyWith(isAuthenticated: true, isLoading: false);
    return true;
  }

  void logout() {
    state = const AdminAuthState();
  }

  /// Temporary demo shortcut used by the prototype mode switcher to jump
  /// straight into the console without the login form.
  void enterDemoSession() {
    state = const AdminAuthState(isAuthenticated: true);
  }

  /// Temporary demo shortcut used by the prototype mode switcher to leave the
  /// console.
  void exitDemoSession() {
    state = const AdminAuthState();
  }
}
