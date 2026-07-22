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

  /// Restaurants promoted from scraped social posts, awaiting admin approval.
  Future<List<Map<String, dynamic>>> getPendingRestaurants({int limit = 50}) async {
    final data = await _supabase
        .from('restaurants')
        .select('*, restaurant_images(image_url)')
        .eq('is_approved', false)
        .order('popularity_score', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Reject a pending restaurant (removes the auto-created row).
  Future<void> rejectRestaurant(String id) async {
    await _supabase.from('restaurants').delete().eq('id', id);
  }

  /// Ingestion pipeline health: how many staged posts are in each state.
  Future<Map<String, int>> getIngestionStats() async {
    final pending = await _supabase
        .from('scraped_posts')
        .count(CountOption.exact)
        .eq('status', 'pending');
    final promoted = await _supabase
        .from('scraped_posts')
        .count(CountOption.exact)
        .eq('status', 'promoted');
    final failed = await _supabase
        .from('scraped_posts')
        .count(CountOption.exact)
        .eq('status', 'failed');
    final skipped = await _supabase
        .from('scraped_posts')
        .count(CountOption.exact)
        .eq('status', 'skipped');

    return {
      'pending': pending,
      'promoted': promoted,
      'failed': failed,
      'skipped': skipped,
    };
  }

  Future<void> deletePost(String id) async {
    await _supabase.from('posts').delete().eq('id', id);
  }

  Future<void> resolveReport(String id, String status) async {
    await _supabase.from('reports').update({'status': status}).eq('id', id);
  }
}
