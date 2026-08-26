import 'package:supabase_flutter/supabase_flutter.dart';

import 'discover_repository.dart';
import 'discover_restaurant.dart';

/// Loads the public restaurant catalogue and its community posts from
/// Supabase. Only approved records are exposed in the customer experience.
class SupabaseDiscoverRepository implements DiscoverRepository {
  SupabaseDiscoverRepository(this._client);

  final SupabaseClient _client;

  static const _restaurantSelect = '''
    id,
    name,
    description,
    address,
    latitude,
    longitude,
    price_range,
    rating,
    created_at,
    is_hidden_gem,
    is_trending,
    is_approved,
    operating_hours,
    phone_number,
    restaurant_images(image_url, is_primary),
    restaurant_categories(categories(name))
  ''';

  @override
  Future<List<DiscoverRestaurant>> loadRestaurants() async {
    final rows = await _client
        .from('restaurants')
        .select(_restaurantSelect)
        .eq('is_approved', true)
        .order('created_at', ascending: false);
    return rows.map(_restaurantFromRow).toList(growable: false);
  }

  @override
  Future<RestaurantDetailsData?> loadRestaurant(String id) async {
    final row = await _client
        .from('restaurants')
        .select(_restaurantSelect)
        .eq('id', int.parse(id))
        .eq('is_approved', true)
        .maybeSingle();
    if (row == null) return null;

    return RestaurantDetailsData(
      restaurant: _restaurantFromRow(row),
      reviews: await _loadReviews(id),
    );
  }

  Future<List<RestaurantReview>> _loadReviews(String restaurantId) async {
    // Community reviews are posts attached to this restaurant. The relation
    // gives us the author and like records in a single read.
    final rows = await _client
        .from('posts')
        .select('''
          id,
          content,
          media_urls,
          user:users!posts_user_id_fkey(username, avatar_url),
          likes(post_id)
        ''')
        .eq('restaurant_id', int.parse(restaurantId))
        .eq('is_hidden', false)
        .order('created_at', ascending: false);

    return rows
        .map((row) {
          final user = row['user'] as Map<String, dynamic>?;
          final mediaUrls = (row['media_urls'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false);
          final likes = row['likes'] as List<dynamic>? ?? const [];
          return RestaurantReview(
            id: '${row['id']}',
            username: user?['username'] as String? ?? 'MakanSpot member',
            profileTitle: 'Community member',
            reviewText: row['content'] as String? ?? '',
            avatarUrl: user?['avatar_url'] as String? ?? '',
            imageUrl: mediaUrls.isEmpty ? '' : mediaUrls.first,
            likes: likes.length,
            isLiked: false,
          );
        })
        .toList(growable: false);
  }

  DiscoverRestaurant _restaurantFromRow(Map<String, dynamic> row) {
    final isHiddenGem = row['is_hidden_gem'] as bool? ?? false;
    final isTrending = row['is_trending'] as bool? ?? false;
    final labels = <String>[
      if (isHiddenGem) 'Hidden Gem',
      if (isTrending) 'Trending',
      if (row['is_approved'] as bool? ?? false) 'Verified',
    ];

    return DiscoverRestaurant(
      id: '${row['id']}',
      name: row['name'] as String? ?? 'Unnamed restaurant',
      cuisine: _cuisineFromRow(row),
      budget: _budgetFromPriceRange(row['price_range'] as String?),
      isHiddenGem: isHiddenGem,
      labels: labels,
      imageUrl: _primaryImageFromRow(row),
      rating: (row['rating'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      address: row['address'] as String? ?? '',
      description: row['description'] as String? ?? '',
      operatingHours: _operatingHoursFromRow(row['operating_hours']),
      contact: row['phone_number'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }

  String _primaryImageFromRow(Map<String, dynamic> row) {
    final images = row['restaurant_images'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? image;
    for (final value in images) {
      if (value is Map<String, dynamic> && value['is_primary'] == true) {
        image = value;
        break;
      }
      image ??= value is Map<String, dynamic> ? value : null;
    }
    return image?['image_url'] as String? ?? '';
  }

  String _cuisineFromRow(Map<String, dynamic> row) {
    final links = row['restaurant_categories'] as List<dynamic>? ?? const [];
    final names = links
        .map((link) => link is Map ? link['categories'] : null)
        .whereType<Map>()
        .map((category) => category['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty);
    return names.isEmpty ? 'Cuisine not provided' : names.join(', ');
  }

  String _budgetFromPriceRange(String? value) => switch (value) {
    r'$' => 'Low',
    r'$$' => 'Medium',
    r'$$$' || r'$$$$' => 'High',
    _ => 'Not specified',
  };

  String _operatingHoursFromRow(dynamic value) {
    if (value is Map) {
      final hours = value.values
          .map((hour) => hour?.toString() ?? '')
          .where((hour) => hour.isNotEmpty)
          .join(', ');
      return hours.isEmpty ? 'Operating hours unavailable' : hours;
    }
    final hours = value?.toString() ?? '';
    return hours.isEmpty ? 'Operating hours unavailable' : hours;
  }
}
