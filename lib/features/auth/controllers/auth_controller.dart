import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_repository.dart';
import '../../../shared/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateChangesProvider = StreamProvider<AuthState>((Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((Ref ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});

// Login state
class LoginState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const LoginState({this.isLoading = false, this.error, this.isSuccess = false});

  LoginState copyWith({bool? isLoading, String? error, bool? isSuccess}) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class LoginController extends StateNotifier<LoginState> {
  final AuthRepository _repository;

  LoginController(this._repository) : super(const LoginState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const LoginState();
  }
}

final loginControllerProvider = StateNotifierProvider<LoginController, LoginState>((Ref ref) {
  return LoginController(ref.watch(authRepositoryProvider));
});

final signOutProvider = Provider<void Function()>((Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return () => repo.signOut();
});

// User profile provider (used by profile feature too)
final userProfileProvider = FutureProvider<UserModel?>((Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).getUserProfile(user.id);
});
