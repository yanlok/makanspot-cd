import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_feed.dart';
import 'home_repository.dart';
import 'restaurant_summary.dart';

class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<HomeFeed> loadHome() async {
    final rows = await _client
        .from('restaurants')
        .select('''
      id, name, categories, price_range, popularity_score, created_at,
      restaurant_images(image_url, is_primary)
    ''')
        .order('created_at', ascending: false)
        .limit(50);

    final ranked = rows
        .map(
          (row) => (
            restaurant: _fromRow(row),
            popularity: (row['popularity_score'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
    final newest = ranked
        .map((item) => item.restaurant)
        .toList(growable: false);
    final recommendedRanked = List.of(ranked)
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    final recommended = recommendedRanked
        .map((item) => item.restaurant)
        .toList(growable: false);

    return HomeFeed(
      firstName:
          _client.auth.currentUser?.userMetadata?['username']?.toString() ??
          'Food Explorer',
      location: 'Malaysia',
      profileAsset: 'assets/images/default_icon.jpg',
      recommended: List.unmodifiable(recommended),
      // The current schema does not define hidden-gem classification or a
      // user-relative distance. Keep these honest until those inputs exist.
      hiddenGems: const [],
      nearby: const [],
      newest: List.unmodifiable(newest),
    );
  }

  RestaurantSummary _fromRow(Map<String, dynamic> row) {
    final categories = row['categories'] as List? ?? const [];
    final images = row['restaurant_images'] as List? ?? const [];
    final primaryImages = images.cast<Map>().where(
      (image) => image['is_primary'] == true,
    );
    final image = primaryImages.isNotEmpty
        ? primaryImages.first
        : (images.isNotEmpty ? images.first as Map : const {});
    return RestaurantSummary(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? 'Restaurant',
      cuisine: categories.isEmpty ? 'Restaurant' : categories.first.toString(),
      budget: _budget(row['price_range']),
      isHiddenGem: false,
      labels: const [],
      imageUrl: image['image_url']?.toString() ?? '',
    );
  }

  String _budget(Object? value) => switch (value?.toString()) {
    r'$' => 'Low',
    r'$$' => 'Medium',
    r'$$$' || r'$$$$' => 'High',
    _ => 'Medium',
  };
}
