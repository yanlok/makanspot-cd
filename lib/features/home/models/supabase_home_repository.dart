import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_feed.dart';
import 'home_repository.dart';
import 'restaurant_summary.dart';

class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<HomeFeed> loadHome() async {
    const restaurantFields = '''
      id, name, categories, price_range, popularity_score, created_at,
      restaurant_images(image_url, is_primary)
    ''';

    final recommendedQuery = _client
        .from('restaurants')
        .select(restaurantFields)
        .isFilter('deleted_at', null)
        .order('popularity_score', ascending: false)
        .limit(50);

    final newestQuery = _client
        .from('restaurants')
        .select(restaurantFields)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(50);

    final user = _client.auth.currentUser;
    Future<({String? username, String? avatarUrl})> fetchUserData() async {
      if (user == null) return (username: null, avatarUrl: null);
      try {
        final row = await _client
            .from('users')
            .select('username, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (row != null) {
          final uname = row['username']?.toString();
          final avatar = row['avatar_url']?.toString();
          return (username: uname, avatarUrl: avatar);
        }
      } catch (_) {}
      final metadata = user.userMetadata ?? const {};
      return (
        username: metadata['username']?.toString() ??
            user.email?.split('@').first,
        avatarUrl: metadata['avatar_url']?.toString(),
      );
    }

    final recommendedRows = await recommendedQuery;
    final newestRows = await newestQuery;
    final userData = await fetchUserData();
    final username = userData.username ?? 'User';
    final avatarUrl = userData.avatarUrl;
    final profileAsset = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : 'assets/images/default_icon.jpg';

    final recommended = recommendedRows
        .map((row) => _fromRow(row, defaultLabels: const ['Popular']))
        .toList(growable: false);
    final newest = newestRows
        .map((row) => _fromRow(row, defaultLabels: const ['NEW']))
        .toList(growable: false);

    return HomeFeed(
      firstName: username,
      location: 'Kuala Lumpur',
      profileAsset: profileAsset,
      recommended: List.unmodifiable(recommended),
      hiddenGems: const [],
      nearby: const [],
      newest: List.unmodifiable(newest),
    );
  }

  RestaurantSummary _fromRow(
    Map<String, dynamic> row, {
    List<String> defaultLabels = const [],
  }) {
    final categories = row['categories'] as List? ?? const [];
    final images = row['restaurant_images'] as List? ?? const [];
    final primaryImages = images.cast<Map>().where(
      (image) => image['is_primary'] == true,
    );
    final image = primaryImages.isNotEmpty
        ? primaryImages.first
        : (images.isNotEmpty ? images.first as Map : const {});
    final popularity = (row['popularity_score'] as num?)?.toInt() ?? 0;
    final labels = defaultLabels.isNotEmpty
        ? defaultLabels
        : (popularity >= 80 ? const ['Popular'] : const <String>[]);
    return RestaurantSummary(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? 'Restaurant',
      cuisine: categories.isEmpty ? 'Restaurant' : categories.first.toString(),
      budget: _budget(row['price_range']),
      isHiddenGem: false,
      labels: labels,
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
