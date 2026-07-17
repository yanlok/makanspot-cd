import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  Future<Map<String, dynamic>> getDashboardStats() async {
    final userCount = await _supabase.from('users').count(CountOption.exact);
    final postCount = await _supabase.from('posts').count(CountOption.exact);
    final restaurantCount = await _supabase.from('restaurants').count(CountOption.exact);
    final reportCount = await _supabase.from('reports').count(CountOption.exact);

    return {
      'total_users': userCount,
      'total_posts': postCount,
      'total_restaurants': restaurantCount,
      'pending_reports': reportCount,
    };
  }

  Future<void> approveRestaurant(String id) async {
    await _supabase.from('restaurants').update({'is_approved': true}).eq('id', id);
  }

  Future<void> deletePost(String id) async {
    await _supabase.from('posts').delete().eq('id', id);
  }

  Future<void> resolveReport(String id, String status) async {
    await _supabase.from('reports').update({'status': status}).eq('id', id);
  }
}
