import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/features/journey/models/badge_catalog.dart';
import 'package:makanspot/shared/models/profile_titles.dart';

import 'profile_models.dart';
import 'profile_repository.dart';

/// Supabase-backed implementation of [ProfileRepository].
///
/// Reads the signed-in user's `public.users` row (created automatically for
/// every auth user on signup), derives profile statistics from the posts and
/// achievements tables, and persists profile edits back to the database.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _userSelect = '''
    id, username, email, bio, avatar_url, community_score, role, is_active
  ''';

  @override
  Future<ProfileData> loadProfile() async {
    final userId = _currentUserId();
    final userRow = await _client
        .from('users')
        .select(_userSelect)
        .eq('id', userId)
        .maybeSingle();
    if (userRow == null) {
      throw const AuthException('Your profile could not be found.');
    }

    final stats = await _loadProfileStats(userId);
    final storedScore = (userRow['community_score'] as num?)?.toInt() ?? 0;
    // Derive the score the same way the Journey screen does: the stored
    // score plus review credits and earned achievement points, so the two
    // screens never disagree.
    final effectiveScore = journeyStyleCommunityScore(
      storedScore: storedScore,
      reviews: stats.reviews,
      distinctRestaurants: stats.visits,
      cuisineCount: stats.cuisines,
      likesReceived: stats.likesReceived,
    );
    final profile = _profileFromRow(userRow, score: effectiveScore);

    return ProfileData(
      profile: profile,
      visits: stats.visits,
      reviews: stats.reviews,
      cuisines: stats.cuisines,
      earnedBadges: stats.earnedBadges,
    );
  }

  @override
  Future<CustomerProfile> saveProfile({
    required String username,
    required String bio,
    required String profileAsset,
  }) async {
    final userId = _currentUserId();
    // Only persist a hosted avatar URL; the bundled fallback asset is never
    // written to the database (an absent avatar is stored as null).
    final avatarUrl = profileAsset.startsWith('http') ? profileAsset : null;
    final updated = await _client
        .from('users')
        .update({
          'username': username,
          'bio': bio,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select(_userSelect);
    if (updated.isEmpty) {
      throw StateError(
        'Profile update affected no rows. Sign in again to refresh your '
        'session.',
      );
    }
    return _profileFromRow(updated.single);
  }

  @override
  Future<String> uploadProfilePicture(ProfilePictureUpload upload) async {
    final userId = _currentUserId();
    final extension = _extensionForMime(upload.mimeType);
    final baseName =
        upload.fileName?.isNotEmpty == true && upload.fileName!.contains('.')
        ? upload.fileName!
        : 'avatar$extension';
    final objectPath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}-'
        '$baseName';

    await _client.storage
        .from('avatars')
        .uploadBinary(
          objectPath,
          upload.bytes,
          fileOptions: FileOptions(contentType: upload.mimeType, upsert: false),
        );
    return _client.storage.from('avatars').getPublicUrl(objectPath);
  }

  String _currentUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to view your profile.');
    }
    return user.id;
  }

  CustomerProfile _profileFromRow(Map<String, dynamic> row, {int? score}) {
    final storedScore = (row['community_score'] as num?)?.toInt() ?? 0;
    final isActive = row['is_active'] as bool? ?? true;
    final avatarUrl = row['avatar_url']?.toString() ?? '';
    return CustomerProfile(
      username: _stringOrEmpty(row['username']),
      email: _stringOrEmpty(row['email']),
      bio: _stringOrEmpty(row['bio']),
      profileAsset: avatarUrl.isEmpty ? defaultProfileAsset : avatarUrl,
      profileTitle: profileTitleForScore(score ?? storedScore),
      role: _stringOrEmpty(row['role']),
      accountStatus: isActive ? 'active' : 'deactivated',
      communityScore: score ?? storedScore,
    );
  }

  Future<ProfileStats> _loadProfileStats(String userId) async {
    // Derived from the user's actual posts. The `journeys` table row is
    // auto-created with zeros and nothing in the app updates it yet, so it
    // cannot be used as the source of these numbers.
    final postRows = await _client
        .from('posts')
        .select('''
          id,
          restaurants!inner(id, categories),
          likes(user_id)
        ''')
        .eq('user_id', userId)
        .eq('is_hidden', false);

    final restaurantIds = <String>{};
    final cuisineNames = <String>{};
    var likesReceived = 0;
    for (final row in postRows) {
      final restaurant = row['restaurants'] as Map<String, dynamic>?;
      final restaurantId = restaurant?['id']?.toString() ?? '';
      if (restaurantId.isNotEmpty) restaurantIds.add(restaurantId);
      final categories = restaurant?['categories'] as List? ?? const [];
      for (final item in categories) {
        final name = item?.toString();
        if (name != null && name.isNotEmpty) cuisineNames.add(name);
      }
      likesReceived += (row['likes'] as List? ?? const []).length;
    }

    return ProfileStats(
      visits: restaurantIds.length,
      reviews: postRows.length,
      cuisines: cuisineNames.length,
      likesReceived: likesReceived,
      earnedBadges: await _loadEarnedBadges(userId),
    );
  }

  Future<List<String>> _loadEarnedBadges(String userId) async {
    try {
      final rows = await _client
          .from('user_achievements')
          .select('achievements(name)')
          .eq('user_id', userId);
      return rows
          .map((row) => (row['achievements'] as Map?)?['name']?.toString())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
    } on Object {
      // Achievements are not part of the minimum schema; an empty badge list
      // just hides the badges section on the profile screen.
      return const [];
    }
  }

  String _stringOrEmpty(dynamic value) => value?.toString() ?? '';

  String _extensionForMime(String mimeType) {
    return switch (mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
  }
}

/// Aggregated statistics displayed alongside the signed-in user's profile.
class ProfileStats {
  const ProfileStats({
    required this.visits,
    required this.reviews,
    required this.cuisines,
    required this.likesReceived,
    required this.earnedBadges,
  });

  final int visits;
  final int reviews;
  final int cuisines;
  final int likesReceived;
  final List<String> earnedBadges;
}
