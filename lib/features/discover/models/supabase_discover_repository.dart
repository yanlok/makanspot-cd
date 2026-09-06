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
          'users!posts_user_id_fkey(username,avatar_url),'
          'likes(user_id)',
        )
        .eq('restaurant_id', id)
        .eq('is_hidden', false)
        .order('created_at', ascending: false);

    return RestaurantDetailsData(
      restaurant: _restaurantFromRow(row),
      reviews: posts
          .map<RestaurantReview>(_reviewFromRow)
          .toList(growable: false),
    );
  }

  @override
  Future<RestaurantReview?> toggleReviewLike(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final existing = await _client
        .from('likes')
        .select('post_id')
        .eq('post_id', int.parse(id))
        .eq('user_id', user.id)
        .maybeSingle();
    if (existing == null) {
      await _client.from('likes').insert({
        'post_id': int.parse(id),
        'user_id': user.id,
      });
    } else {
      await _client
          .from('likes')
          .delete()
          .eq('post_id', int.parse(id))
          .eq('user_id', user.id);
    }
    final row = await _client
        .from('posts')
        .select(
          'id,content,media_urls,rating,'
          'users!posts_user_id_fkey(username,avatar_url),'
          'likes(user_id)',
        )
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _reviewFromRow(row);
  }

  @override
  Future<Set<String>> loadBookmarkedRestaurantIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return const {};
    final rows = await _client
        .from('bookmarks')
        .select('restaurant_id')
        .eq('user_id', user.id)
        .not('restaurant_id', 'is', null);
    return rows
        .map<String>((row) => row['restaurant_id'].toString())
        .toSet();
  }

  @override
  Future<void> setRestaurantBookmark(
    String restaurantId, {
    required bool saved,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final restaurantIdValue = int.parse(restaurantId);
    if (saved) {
      final existing = await _client
          .from('bookmarks')
          .select('id')
          .eq('user_id', user.id)
          .eq('restaurant_id', restaurantIdValue)
          .maybeSingle();
      if (existing != null) return;
      await _client.from('bookmarks').insert({
        'user_id': user.id,
        'restaurant_id': restaurantIdValue,
      });
    } else {
      await _client
          .from('bookmarks')
          .delete()
          .eq('user_id', user.id)
          .eq('restaurant_id', restaurantIdValue);
    }
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
    final likes = row['likes'] as List? ?? const [];
    final currentUserId = _client.auth.currentUser?.id;
    return RestaurantReview(
      id: row['id'].toString(),
      username: user['username']?.toString() ?? 'Food explorer',
      profileTitle: 'Food explorer',
      reviewText: row['content']?.toString() ?? '',
      avatarUrl: user['avatar_url']?.toString() ?? '',
      imageUrl: mediaUrls.isEmpty ? '' : mediaUrls.first.toString(),
      likes: likes.length,
      isLiked:
          currentUserId != null &&
          likes.any((like) => (like as Map)['user_id'] == currentUserId),
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
