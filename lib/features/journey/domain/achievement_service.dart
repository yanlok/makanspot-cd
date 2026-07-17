import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/journey_repository.dart';

class AchievementService {
  final JourneyRepository _repository;
  final SupabaseClient _supabase;

  AchievementService(this._repository, this._supabase);

  Future<void> checkAndUnlockAchievements() async {
    final userId = _supabase.auth.currentUser!.id;
    final stats = await _repository.getUserStats(userId);
    
    // 1. Food Explorer (5 restaurants)
    if (stats['restaurants_visited'] >= 5) {
      await _unlockAchievement(userId, 'Food Explorer');
    }

    // 2. Hidden Gem Hunter (3 gems)
    // This would require a count from reviews joined with hidden gems
    // Simplified for this demo
    
    // 3. Top Reviewer (10 reviews)
    if (stats['reviews_written'] >= 10) {
      await _unlockAchievement(userId, 'Top Reviewer');
    }
  }

  Future<void> _unlockAchievement(String userId, String achievementName) async {
    // Check if already unlocked
    final achievement = await _supabase
        .from('achievements')
        .select()
        .eq('name', achievementName)
        .single();
    
    final existing = await _supabase
        .from('user_achievements')
        .select()
        .eq('user_id', userId)
        .eq('achievement_id', achievement['id'])
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('user_achievements').insert({
        'user_id': userId,
        'achievement_id': achievement['id'],
      });

      // Update community score
      await _supabase.rpc('increment_community_score', params: {
        'row_id': userId,
        'increment_by': achievement['points']
      });
    }
  }
}
