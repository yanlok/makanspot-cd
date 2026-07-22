import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((Ref ref) {
  return AdminRepository(Supabase.instance.client);
});

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((Ref ref) async {
  return ref.watch(adminRepositoryProvider).getDashboardStats();
});
