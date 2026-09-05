import 'package:supabase_flutter/supabase_flutter.dart';

import 'discover_repository.dart';
import 'discover_restaurant.dart';

class SupabaseDiscoverRepository implements DiscoverRepository {
  SupabaseDiscoverRepository(this._client);

  final SupabaseClient _client;

  static const _restaurantSelect = '''
    id, name, description, address, city, state, latitude, longitude,
    phone, price_range, categories, business_hours, popularity_score,
    google_maps_url,
    created_at,
    restaurant_images(image_url, is_primary)
  ''';

  @override
  Future<List<DiscoverRestaurant>> loadRestaurants() async {
    final rows = await _client
        .from('restaurants')
        .select(_restaurantSelect)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return rows
        .map<DiscoverRestaurant>(_restaurantFromRow)
        .toList(growable: false);
  }

  @override
  Future<RestaurantDetailsData?> loadRestaurant(String id) async {
    final row = await _client
        .from('restaurants')
        .select(_restaurantSelect)
        .isFilter('deleted_at', null)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final posts = await _client
        .from('posts')
        .select(
          'id,content,media_urls,rating,'
          'users!posts_user_id_fkey(username,avatar_url)',
        )
        .eq('restaurant_id', id)
        .order('created_at', ascending: false);

    return RestaurantDetailsData(
      restaurant: _restaurantFromRow(row),
      reviews: posts
          .map<RestaurantReview>(_reviewFromRow)
          .toList(growable: false),
    );
  }

  DiscoverRestaurant _restaurantFromRow(Map<String, dynamic> row) {
    final categories = (row['categories'] as List?)
        ?.map((category) => category.toString())
        .where((category) => category.isNotEmpty)
        .toList(growable: false) ??
        const <String>[];
    final images = row['restaurant_images'] as List? ?? const [];
    final image = images.cast<Map>().firstWhere(
      (item) => item['is_primary'] == true,
      orElse: () =>
          images.cast<Map>().isNotEmpty ? images.cast<Map>().first : const {},
    );
    final cuisine = categories.firstOrNull ?? 'Restaurant';

    return DiscoverRestaurant(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? 'Restaurant',
      cuisine: cuisine,
      categories: categories,
      city: row['city']?.toString(),
      popularityScore: (row['popularity_score'] as num?)?.toInt() ?? 0,
      budget: _budget(row['price_range']),
      isHiddenGem: false,
      labels: const [],
      imageUrl: image['image_url']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      address: row['address']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      operatingHours: _operatingHours(row['business_hours']),
      contact: row['phone']?.toString(),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      googleMapsUrl: row['google_maps_url']?.toString(),
    );
  }

  RestaurantReview _reviewFromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map? ?? const {};
    final mediaUrls = row['media_urls'] as List? ?? const [];
    return RestaurantReview(
      id: row['id'].toString(),
      username: user['username']?.toString() ?? 'Food explorer',
      profileTitle: 'Food explorer',
      reviewText: row['content']?.toString() ?? '',
      avatarUrl: user['avatar_url']?.toString() ?? '',
      imageUrl: mediaUrls.isEmpty ? '' : mediaUrls.first.toString(),
      likes: 0,
      isLiked: false,
    );
  }

  String _budget(Object? value) {
    return switch (value?.toString()) {
      r'$' || '1' => 'Low',
      r'$$' || '2' => 'Medium',
      r'$$$' || r'$$$$' || '3' || '4' => 'High',
      _ => '',
    };
  }

  String _operatingHours(Object? value) {
    if (value == null) return '';
    final formatted = formatOperatingHours(value);
    return formatted == '-' ? '' : formatted;
  }
}
