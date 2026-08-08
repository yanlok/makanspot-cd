import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'admin_repository.dart';

/// Supabase-backed implementation of [AdminRepository].
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  static const _reportSelect = '''
    id,
    reason,
    additional_info,
    created_at,
    post_id,
    comment_id,
    reporter:users!reports_reporter_id_fkey(username)
  ''';

  // ── Reports (grouped) ────────────────────────────────────────────

  @override
  Future<List<ReportedContentGroup>> loadReportedContentGroups() async {
    final rows = await _client
        .from('reports')
        .select(_reportSelect)
        .isFilter('dismissed_at', null)
        .order('created_at', ascending: false);

    return _groupByContent(rows);
  }

  @override
  Future<ReportedContentGroup?> loadReportedContentGroup(
    String contentId,
    ReportContentType contentType,
  ) async {
    final column = contentType == ReportContentType.post
        ? 'post_id'
        : 'comment_id';

    final rows = await _client
        .from('reports')
        .select(_reportSelect)
        .eq(column, int.parse(contentId))
        .isFilter('dismissed_at', null)
        .order('created_at', ascending: false);

    if (rows.isEmpty) return null;

    final groups = await _groupByContent(rows);
    return groups.isEmpty ? null : groups.first;
  }

  @override
  Future<ReportedContent?> loadReportedContent(
    ReportedContentGroup group,
  ) async {
    if (group.contentType == ReportContentType.post) {
      return _loadPostContent(group.contentId);
    }
    return _loadCommentContent(group.contentId);
  }

  @override
  Future<void> removeContent(
    String contentId,
    ReportContentType contentType,
  ) async {
    final table = contentType == ReportContentType.post ? 'posts' : 'comments';
    final updated = await _client
        .from(table)
        .update({'is_hidden': true})
        .eq('id', int.parse(contentId))
        .select();
    if (updated.isEmpty) {
      throw StateError(
        'Content moderation update affected no rows. The signed-in '
        'account may lack admin permissions.',
      );
    }
  }

  @override
  Future<void> dismissReports(
    String contentId,
    ReportContentType contentType,
  ) async {
    final column = contentType == ReportContentType.post
        ? 'post_id'
        : 'comment_id';
    // Soft delete: mark the reports as dismissed so they leave the
    // moderation queue but remain in the table for audit.
    final updated = await _client
        .from('reports')
        .update({'dismissed_at': DateTime.now().toUtc().toIso8601String()})
        .eq(column, int.parse(contentId))
        .select();
    if (updated.isEmpty) {
      throw StateError(
        'Report dismissal affected no rows. The signed-in account may '
        'lack admin permissions.',
      );
    }
  }

  // ── Dashboard ────────────────────────────────────────────────────

  @override
  Future<AdminDashboardData> loadDashboard() async {
    final counts = await Future.wait([
      _client.from('users').select('id').count(),
      _client.from('restaurants').select('id').count(),
      _client.from('posts').select('id').count(),
      _client.from('comments').select('id').count(),
    ]);
    final pendingCount = await _countPendingReports();

    final allGroups = await loadReportedContentGroups();
    final pendingGroups = allGroups.where((g) => !g.isRemoved).take(5).toList();

    return AdminDashboardData(
      userCount: counts[0].count,
      restaurantCount: counts[1].count,
      postCount: counts[2].count,
      commentCount: counts[3].count,
      pendingReportCount: pendingCount,
      recentReports: pendingGroups,
    );
  }

  Future<int> _countPendingReports() async {
    // Count distinct post_ids that have active (non-dismissed) reports
    // and are not hidden.
    final postRows = await _client
        .from('reports')
        .select('post_id')
        .not('post_id', 'is', null)
        .isFilter('dismissed_at', null);

    final commentRows = await _client
        .from('reports')
        .select('comment_id')
        .not('comment_id', 'is', null)
        .isFilter('dismissed_at', null);

    final postIds = <int>{};
    for (final row in postRows) {
      final id = row['post_id'] as int?;
      if (id != null) postIds.add(id);
    }

    final commentIds = <int>{};
    for (final row in commentRows) {
      final id = row['comment_id'] as int?;
      if (id != null) commentIds.add(id);
    }

    int count = 0;
    if (postIds.isNotEmpty) {
      final result = await _client
          .from('posts')
          .select('id')
          .inFilter('id', postIds.toList())
          .eq('is_hidden', false);
      count += result.length;
    }
    if (commentIds.isNotEmpty) {
      final result = await _client
          .from('comments')
          .select('id')
          .inFilter('id', commentIds.toList())
          .eq('is_hidden', false);
      count += result.length;
    }
    return count;
  }

  // ── Users ────────────────────────────────────────────────────────

  @override
  Future<List<AdminUser>> loadUsers() async {
    final rows = await _client.from('users').select().order('username');
    return rows.map(_userFromRow).toList(growable: false);
  }

  @override
  Future<AdminUser?> loadUser(String id) async {
    final row = await _client.from('users').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _userFromRow(row);
  }

  @override
  Future<AdminUser?> updateUser({
    required String id,
    required String username,
    required String profileTitle,
    required int communityScore,
  }) {
    throw UnimplementedError('User update is not yet supported via Supabase.');
  }

  @override
  Future<AdminUser?> setUserAccountStatus(
    String id,
    AdminAccountStatus status,
  ) {
    throw UnimplementedError(
      'Account status toggle is not yet supported via Supabase.',
    );
  }

  // ── Restaurants ──────────────────────────────────────────────────

  @override
  Future<List<AdminRestaurant>> loadRestaurants() async {
    final rows = await _client
        .from('restaurants')
        .select('''
              id,
              name,
              description,
              address,
              latitude,
              longitude,
              price_range,
              rating,
              operating_hours,
              phone_number,
              social_media_source,
              is_verified,
              restaurant_images!inner(image_url, is_primary)
            ''')
        .order('name');
    return rows.map(_restaurantFromRow).toList(growable: false);
  }

  @override
  Future<AdminRestaurant?> loadRestaurant(String id) async {
    final row = await _client
        .from('restaurants')
        .select('''
              id,
              name,
              description,
              address,
              latitude,
              longitude,
              price_range,
              rating,
              operating_hours,
              phone_number,
              social_media_source,
              is_verified,
              restaurant_images!inner(image_url, is_primary)
            ''')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _restaurantFromRow(row);
  }

  @override
  Future<AdminRestaurant> createRestaurant(AdminRestaurantDraft draft) {
    throw UnimplementedError(
      'Restaurant creation is not yet supported via Supabase.',
    );
  }

  @override
  Future<AdminRestaurant?> updateRestaurant(
    String id,
    AdminRestaurantDraft draft,
  ) {
    throw UnimplementedError(
      'Restaurant update is not yet supported via Supabase.',
    );
  }

  @override
  Future<void> deleteRestaurant(String id) {
    throw UnimplementedError(
      'Restaurant deletion is not yet supported via Supabase.',
    );
  }

  // ── Private helpers ──────────────────────────────────────────────

  Future<List<ReportedContentGroup>> _groupByContent(
    List<Map<String, dynamic>> rows,
  ) async {
    final map = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final postId = row['post_id'];
      final commentId = row['comment_id'];
      final contentType = commentId != null
          ? ReportContentType.comment
          : ReportContentType.post;
      final contentId = commentId != null ? '$commentId' : '$postId';
      // Key by type too: post and comment IDs share separate identity
      // sequences, so a post and a comment can have the same numeric ID.
      final key = '${contentType.name}:$contentId';

      if (!map.containsKey(key)) {
        map[key] = {
          'contentId': contentId,
          'contentType': contentType,
          'reports': <Map<String, dynamic>>[],
        };
      }
      (map[key]!['reports'] as List<Map<String, dynamic>>).add(row);
    }

    // Fetch content preview, owner, and is_hidden for each group.
    return Future.wait(
      map.values.map((entry) async {
        final contentId = entry['contentId'] as String;
        final contentType = entry['contentType'] as ReportContentType;

        String preview = '';
        String owner = '';
        bool isRemoved = false;

        if (contentType == ReportContentType.post) {
          final post = await _client
              .from('posts')
              .select(
                'content, is_hidden, user:users!posts_user_id_fkey(username)',
              )
              .eq('id', int.parse(contentId))
              .maybeSingle();
          if (post != null) {
            preview = post['content'] as String? ?? '';
            owner =
                (post['user'] as Map<String, dynamic>?)?['username']
                    as String? ??
                '';
            isRemoved = post['is_hidden'] as bool? ?? false;
          }
        } else {
          final comment = await _client
              .from('comments')
              .select(
                'content, is_hidden, user:users!comments_user_id_fkey(username)',
              )
              .eq('id', int.parse(contentId))
              .maybeSingle();
          if (comment != null) {
            preview = comment['content'] as String? ?? '';
            owner =
                (comment['user'] as Map<String, dynamic>?)?['username']
                    as String? ??
                '';
            isRemoved = comment['is_hidden'] as bool? ?? false;
          }
        }

        final reports = (entry['reports'] as List<Map<String, dynamic>>)
            .map(_individualReportFromRow)
            .toList();

        return ReportedContentGroup(
          contentId: contentId,
          contentType: contentType,
          contentPreview: preview,
          contentOwner: owner,
          isRemoved: isRemoved,
          reports: reports,
        );
      }),
    ).then((groups) {
      // Sort: pending first, then by report count descending.
      groups.sort((a, b) {
        if (a.isRemoved != b.isRemoved) return a.isRemoved ? 1 : -1;
        return b.reports.length.compareTo(a.reports.length);
      });
      return groups;
    });
  }

  ModerationReport _individualReportFromRow(Map<String, dynamic> row) {
    final reporter = row['reporter'] as Map<String, dynamic>?;
    return ModerationReport(
      id: '${row['id']}',
      reporterName: _stringOrEmpty(reporter?['username']),
      reason: _stringOrEmpty(row['reason']),
      createdDate: DateTime.parse(row['created_at'] as String),
      additionalInfo: row['additional_info'] as String?,
    );
  }

  AdminUser _userFromRow(Map<String, dynamic> row) {
    return AdminUser(
      id: row['id'] as String,
      username: _stringOrEmpty(row['username']),
      email: _stringOrEmpty(row['email']),
      profilePictureUrl:
          row['avatar_url'] as String? ?? 'assets/images/default_icon.jpg',
      profileTitle: _profileTitleFromScore(
        (row['community_score'] as num?)?.toInt() ?? 0,
      ),
      communityScore: (row['community_score'] as num?)?.toInt() ?? 0,
      accountStatus: AdminAccountStatus.active,
    );
  }

  AdminRestaurant _restaurantFromRow(Map<String, dynamic> row) {
    final images = row['restaurant_images'] as List<dynamic>?;
    final primaryImage = images?.cast<Map<String, dynamic>>().firstWhere(
      (img) => img['is_primary'] == true,
      orElse: () => {'image_url': ''},
    );
    final imageUrl = primaryImage?['image_url'] as String? ?? '';

    final hours = row['operating_hours'];
    String operatingHours;
    if (hours is Map) {
      operatingHours = hours.values
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(', ');
    } else {
      operatingHours = hours?.toString() ?? '';
    }

    return AdminRestaurant(
      id: '${row['id']}',
      name: _stringOrEmpty(row['name']),
      cuisine: row['social_media_source'] as String? ?? '',
      address: _stringOrEmpty(row['address']),
      imageUrl: imageUrl,
      operatingHours: operatingHours,
      contact: row['phone_number'] as String? ?? '',
      budget: row['price_range'] as String? ?? '',
      description: row['description'] as String? ?? '',
      sourcePlatform: row['social_media_source'] as String? ?? 'Manual',
      isVerified: row['is_verified'] as bool? ?? false,
      rating: (row['rating'] as num?)?.toDouble(),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }

  Future<ReportedContent?> _loadPostContent(String postId) async {
    final row = await _client
        .from('posts')
        .select('''
              id,
              content,
              media_urls,
              user:users!posts_user_id_fkey(username),
              restaurant:restaurants!posts_restaurant_id_fkey(name)
            ''')
        .eq('id', postId)
        .maybeSingle();
    if (row == null) return null;

    final user = row['user'] as Map<String, dynamic>?;
    final restaurant = row['restaurant'] as Map<String, dynamic>?;
    final mediaUrls =
        (row['media_urls'] as List<dynamic>?)?.cast<String>() ?? [];

    return ReportedContent(
      username: _stringOrEmpty(user?['username']),
      restaurantName: restaurant?['name'] as String?,
      text: row['content'] as String? ?? '',
      mediaUrls: mediaUrls,
    );
  }

  Future<ReportedContent?> _loadCommentContent(String commentId) async {
    final row = await _client
        .from('comments')
        .select('''
              id,
              content,
              user:users!comments_user_id_fkey(username),
              post:posts!comments_post_id_fkey(
                content,
                restaurants!posts_restaurant_id_fkey(name)
              )
            ''')
        .eq('id', commentId)
        .maybeSingle();
    if (row == null) return null;

    final user = row['user'] as Map<String, dynamic>?;
    final post = row['post'] as Map<String, dynamic>?;
    final restaurant = post?['restaurants'] as Map<String, dynamic>?;
    return ReportedContent(
      username: _stringOrEmpty(user?['username']),
      restaurantName: restaurant?['name'] as String?,
      postPreview: post?['content'] as String?,
      text: row['content'] as String? ?? '',
      mediaUrls: const [],
    );
  }

  String _stringOrEmpty(dynamic value) => value?.toString() ?? '';

  String _profileTitleFromScore(int score) {
    if (score >= 200) return 'Food Legend';
    if (score >= 150) return 'Makan Master';
    if (score >= 100) return 'Flavour Explorer';
    if (score >= 50) return 'Taste Tester';
    return 'New Foodie';
  }
}
