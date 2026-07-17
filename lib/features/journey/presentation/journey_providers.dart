import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/journey_repository.dart';

final journeyRepositoryProvider = Provider((Ref ref) {
  return JourneyRepository(Supabase.instance.client);
});

final userStatsProvider = FutureProvider<Map<String, dynamic>>((Ref ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {};
  return ref.watch(journeyRepositoryProvider).getUserStats(user.id);
});

final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.watch(journeyRepositoryProvider).getLeaderboard();
});

final userAchievementsProvider = FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  return ref.watch(journeyRepositoryProvider).getAchievements(user.id);
});
