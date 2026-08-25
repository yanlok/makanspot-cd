import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'discover_repository.dart';
import 'discover_restaurant.dart';
import 'fixture_discover_repository.dart';

class SupabaseDiscoverRepository implements DiscoverRepository {
  SupabaseDiscoverRepository(
    this._client, {
    DiscoverRepository fallback = const FixtureDiscoverRepository(),
  }) : _fallback = fallback;

  final SupabaseClient _client;
  final DiscoverRepository _fallback;

  static const _restaurantSelect = '''
    id, name, description, address, city, state, latitude, longitude,
    phone, price_range, categories, business_hours, popularity_score,
    is_approved, created_at,
    restaurant_images(image_url, is_primary)
  ''';

  @override
  Future<List<DiscoverRestaurant>> loadRestaurants() async {
    try {
      final rows = await _client
          .from('restaurants')
          .select(_restaurantSelect)
          .order('created_at', ascending: false);

      if (rows.isEmpty) return _fallback.loadRestaurants();
      return rows
          .map<DiscoverRestaurant>(_restaurantFromRow)
          .toList(growable: false);
    } on Object {
      return _fallback.loadRestaurants();
    }
  }

  @override
  Future<RestaurantDetailsData?> loadRestaurant(String id) async {
    try {
      final row = await _client
          .from('restaurants')
          .select(_restaurantSelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return _fallback.loadRestaurant(id);

      final posts = await _client
          .from('posts')
          .select('id,content,media_urls,rating,users(username,avatar_url)')
          .eq('restaurant_id', id)
          .order('created_at', ascending: false);

      return RestaurantDetailsData(
        restaurant: _restaurantFromRow(row),
        reviews: posts
            .map<RestaurantReview>(_reviewFromRow)
            .toList(growable: false),
      );
    } on Object {
      return _fallback.loadRestaurant(id);
    }
  }

  DiscoverRestaurant _restaurantFromRow(Map<String, dynamic> row) {
    final categories = (row['categories'] as List?)
        ?.map((category) => category.toString())
        .where((category) => category.isNotEmpty)
        .toList(growable: false);
    final images = row['restaurant_images'] as List? ?? const [];
    final image = images.cast<Map>().firstWhere(
      (item) => item['is_primary'] == true,
      orElse: () =>
          images.cast<Map>().isNotEmpty ? images.cast<Map>().first : const {},
    );
    final cuisine = categories?.firstOrNull ?? 'Restaurant';

    return DiscoverRestaurant(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? 'Restaurant',
      cuisine: cuisine,
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
      r'$' => 'Low',
      r'$$' => 'Medium',
      r'$$$' || r'$$$$' => 'High',
      _ => 'Medium',
    };
  }

  String _operatingHours(Object? value) {
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return '';
  }
}
