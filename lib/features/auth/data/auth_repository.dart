import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/user_model.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    // Create user profile in public.users table
    if (response.user != null) {
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'username': username,
        'email': email,
      });
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<UserModel?> getUserProfile(String id) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('id', id)
        .single();
    return UserModel.fromJson(data);
  }
}
