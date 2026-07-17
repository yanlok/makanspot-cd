import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../shared/models/user_model.dart';

final userProfileProvider = FutureProvider<UserModel?>((Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).getUserProfile(user.id);
});
