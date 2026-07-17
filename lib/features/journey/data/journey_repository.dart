import 'package:supabase_flutter/supabase_flutter.dart';

class JourneyRepository {
  final SupabaseClient _supabase;

  JourneyRepository(this._supabase);

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final data = await _supabase
        .from('journeys')
        .select()
        .eq('user_id', userId)
        .single();
    return data;
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final data = await _supabase
        .from('users')
        .select('username, avatar_url, community_score')
        .order('community_score', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getAchievements(String userId) async {
    final data = await _supabase
        .from('user_achievements')
        .select('*, achievements(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(data);
  }
}
