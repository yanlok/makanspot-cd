import 'package:supabase_flutter/supabase_flutter.dart';

import 'journey_models.dart';
import 'journey_repository.dart';

class SupabaseJourneyRepository implements JourneyRepository {
  SupabaseJourneyRepository(this._client);

  final SupabaseClient _client;

  static const _visitedSelect = '''
    id, content, rating, created_at,
    restaurants!posts_restaurant_id_fkey(
      id, name, address, latitude, longitude, price_range, rating,
      restaurant_images(image_url, is_primary),
      restaurant_categories(categories(name))
    )
  ''';

  @override
  Future<JourneyData> loadJourney() async {
    final userRow = await _client
        .from('users')
        .select('username,email,avatar_url,community_score')
        .eq('id', _user.id)
        .maybeSingle();
    final postRows = await _client
        .from('posts')
        .select(_visitedSelect)
        .eq('user_id', _user.id)
        .not('restaurants', 'is', null)
        .order('created_at', ascending: false);
    final likeRows = await _client
        .from('posts')
        .select('likes(user_id)')
        .eq('user_id', _user.id);

    final user = userRow ?? const {};
    final visits = postRows.map<JourneyVisit>(_visitFromRow).toList();
    final locations = <JourneyLocation>[
      for (final row in postRows) ?_locationFromRow(row),
    ];
    final totalLikes = likeRows.fold<int>(
      0,
      (sum, row) => sum + ((row['likes'] as List? ?? const []).length),
    );

    return JourneyData(
      user: JourneyUser(
        username: user['username']?.toString() ?? 'Food explorer',
        email: user['email']?.toString() ?? '',
        profileTitle: _profileTitle(user['community_score'] as int? ?? 0),
        communityScore: user['community_score'] as int? ?? 0,
        profileAsset:
            user['avatar_url']?.toString() ?? 'assets/images/default_icon.jpg',
      ),
      visits: visits,
      locations: locations,
      reviewCount: visits.length,
      totalLikes: totalLikes,
      // The achievements and score history are not modelled in the
      // database yet; the journey screens handle empty lists gracefully.
      achievements: const [],
      scoreHistory: const [],
    );
  }

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to view your journey.');
    }
    return user;
  }

  JourneyVisit _visitFromRow(Map<String, dynamic> row) {
    final restaurant = row['restaurants'] as Map<String, dynamic>? ?? const {};
    return JourneyVisit(
      id: row['id'].toString(),
      restaurantId: restaurant['id']?.toString() ?? '',
      restaurantName: restaurant['name']?.toString() ?? 'Restaurant',
      restaurantImage: _primaryImage(restaurant),
      cuisine: _cuisine(restaurant),
      visitDate:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      postId: row['id'].toString(),
    );
  }

  JourneyLocation? _locationFromRow(Map<String, dynamic> row) {
    final restaurant = row['restaurants'] as Map<String, dynamic>? ?? const {};
    final latitude = restaurant['latitude'] as num?;
    final longitude = restaurant['longitude'] as num?;
    if (latitude == null || longitude == null) return null;
    return JourneyLocation(
      id: restaurant['id'].toString(),
      name: restaurant['name']?.toString() ?? 'Restaurant',
      cuisine: _cuisine(restaurant),
      imageUrl: _primaryImage(restaurant),
      address: restaurant['address']?.toString() ?? '',
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  String _cuisine(Map<String, dynamic> restaurant) {
    final categories = restaurant['restaurant_categories'] as List? ?? const [];
    for (final item in categories) {
      final category = (item as Map?)?['categories'] as Map?;
      final name = category?['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return '';
  }

  String _primaryImage(Map<String, dynamic> restaurant) {
    final images = restaurant['restaurant_images'] as List? ?? const [];
    if (images.isEmpty) return '';
    final primary = images.cast<Map>().where(
      (item) => item['is_primary'] == true,
    );
    final selected = primary.isNotEmpty ? primary.first : images.first;
    return selected['image_url']?.toString() ?? '';
  }

  String _profileTitle(int score) {
    if (score >= 500) return 'Makan Legend';
    if (score >= 100) return 'Hidden Gem Hunter';
    return 'Food Explorer';
  }
}
