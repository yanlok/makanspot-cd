import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateChangesProvider = StreamProvider<AuthState>((Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((Ref ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});
