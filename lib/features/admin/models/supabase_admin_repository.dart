import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'admin_repository.dart';

/// Supabase-backed implementation of [AdminRepository].
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get restaurantUpdatesAreAutomaticallyAudited => true;

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
  ) async {
    final isPost = await _contentIsPost(contentId);
    final column = isPost ? 'post_id' : 'comment_id';

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
  Future<void> removeContent(String contentId) async {
    final isPost = await _contentIsPost(contentId);
    final table = isPost ? 'posts' : 'comments';
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
  Future<void> dismissReports(String contentId) async {
    final isPost = await _contentIsPost(contentId);
    final column = isPost ? 'post_id' : 'comment_id';
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
    required String email,
    required String phone,
    required AdminUserRole role,
    required int communityScore,
  }) async {
    final updated = await _client
        .from('users')
        .update({
          'username': username,
          'email': email,
          'phone_number': phone.trim().isEmpty ? null : phone.trim(),
          'role': role.value,
          'community_score': communityScore,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select();
    if (updated.isEmpty) {
      throw StateError(
        'User update affected no rows. The signed-in account may lack '
        'admin permissions.',
      );
    }
    return _userFromRow(updated.single);
  }

  @override
  Future<AdminUser?> setUserAccountStatus(
    String id,
    AdminAccountStatus status,
  ) async {
    final updated = await _client
        .from('users')
        .update({
          'is_active': status == AdminAccountStatus.active,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select();
    if (updated.isEmpty) {
      throw StateError(
        'Account status update affected no rows. The signed-in account may '
        'lack admin permissions.',
      );
    }
    return _userFromRow(updated.single);
  }

  @override
  Future<bool> usernameExists(String username, String excludeUserId) async {
    final rows = await _client
        .from('users')
        .select('id')
        .ilike('username', username)
        .neq('id', excludeUserId);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> emailExists(String email, String excludeUserId) async {
    final rows = await _client
        .from('users')
        .select('id')
        .eq('email', email)
        .neq('id', excludeUserId);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> phoneExists(String phone, String excludeUserId) async {
    final rows = await _client
        .from('users')
        .select('id')
        .eq('phone_number', phone)
        .neq('id', excludeUserId);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> restaurantNameExists(
    String name, {
    String? excludeRestaurantId,
  }) async {
    // Avoid an `ilike` filter here: a restaurant name can legitimately
    // contain PostgREST wildcard characters. Comparing the small set of IDs
    // and names locally is exact and works on every deployed schema.
    final rows = await _client.from('restaurants').select('id, name');
    final normalizedName = _normalizeRestaurantName(name);
    return rows.any(
      (row) =>
          '${row['id']}' != excludeRestaurantId &&
          _normalizeRestaurantName(_stringOrEmpty(row['name'])) ==
              normalizedName,
    );
  }

  @override
  Future<void> logAdminAction({
    required String adminUserId,
    required String adminUsername,
    required String action,
    String? targetUserId,
    required String targetUsername,
    Map<String, Map<String, Object?>>? fieldChanges,
  }) async {
    final values = <String, Object?>{
      'admin_user_id': adminUserId,
      'admin_username': adminUsername,
      'action': action,
      'target_username': targetUsername,
      'field_changes': fieldChanges ?? {},
    };
    if (targetUserId != null) values['target_user_id'] = targetUserId;
    await _client.from('admin_audit_log').insert(values);
  }

  @override
  Future<List<AdminAuditLog>> loadAdminActionLogs() async {
    final rows = await _client
        .from('admin_audit_log')
        .select()
        .order('created_at', ascending: false);
    return rows.map(_auditLogFromRow).toList(growable: false);
  }

  // ── Restaurants ──────────────────────────────────────────────────

  @override
  Future<List<AdminRestaurant>> loadRestaurants() async {
    // The production database has evolved independently from the original
    // app schema. In particular, some deployments do not expose the
    // `restaurant_categories` relationship (or fields such as `rating`).
    // Selecting the base record keeps the admin catalogue available across
    // both schema versions; optional image data is fetched separately below.
    final rows = await _client.from('restaurants').select().order('name');
    final primaryImages = await _loadPrimaryImages(
      rows.map((row) => row['id']),
    );

    return rows
        .map(
          (row) => _restaurantFromRow(
            row,
            primaryImageUrl: primaryImages['${row['id']}'],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AdminRestaurant?> loadRestaurant(String id) async {
    final row = await _client
        .from('restaurants')
        .select()
        .eq('id', int.tryParse(id) ?? id)
        .maybeSingle();
    if (row == null) return null;
    final primaryImages = await _loadPrimaryImages([row['id']]);
    return _restaurantFromRow(
      row,
      primaryImageUrl: primaryImages['${row['id']}'],
    );
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
    AdminRestaurantDraft draft, {
    Set<String>? changedFields,
  }) async {
    final restaurantId = int.tryParse(id) ?? id;
    Map<String, dynamic> row;
    try {
      // Current production schema. It stores categories and business hours
      // directly on `restaurants` rather than via the original join table.
      final updated = await _client
          .from('restaurants')
          .update(_currentRestaurantPayload(draft, changedFields))
          .eq('id', restaurantId)
          .select();
      if (updated.isEmpty) {
        throw const RestaurantUpdateNoRowsException();
      }
      row = updated.single;
    } on PostgrestException catch (error) {
      if (!_isMissingColumn(error)) rethrow;
      // Compatibility with the original MakanSpot schema used by local and
      // older Supabase deployments.
      final updated = await _client
          .from('restaurants')
          .update(_legacyRestaurantPayload(draft, changedFields))
          .eq('id', restaurantId)
          .select();
      if (updated.isEmpty) {
        throw const RestaurantUpdateNoRowsException();
      }
      row = updated.single;
    }

    final primaryImages = await _loadPrimaryImages([row['id']]);
    final existingImageUrl = primaryImages['${row['id']}'] ?? '';
    final requestedImageUrl = draft.imageUrl.trim();
    if (requestedImageUrl.isNotEmpty &&
        requestedImageUrl != existingImageUrl.trim()) {
      await _persistPrimaryImage(row['id'], requestedImageUrl);
    }
    return _restaurantFromRow(
      row,
      primaryImageUrl: requestedImageUrl.isNotEmpty
          ? requestedImageUrl
          : primaryImages['${row['id']}'],
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
      final contentId = commentId != null ? '$commentId' : '$postId';
      final contentType = commentId != null
          ? ReportContentType.comment
          : ReportContentType.post;

      if (!map.containsKey(contentId)) {
        map[contentId] = {
          'contentId': contentId,
          'contentType': contentType,
          'reports': <Map<String, dynamic>>[],
        };
      }
      (map[contentId]!['reports'] as List<Map<String, dynamic>>).add(row);
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
    final createdAt = row['created_at'] as String?;
    final isActive = row['is_active'] as bool? ?? true;
    return AdminUser(
      id: row['id'] as String,
      username: _stringOrEmpty(row['username']),
      email: _stringOrEmpty(row['email']),
      profilePictureUrl:
          row['avatar_url'] as String? ?? 'assets/images/default_icon.jpg',
      communityScore: (row['community_score'] as num?)?.toInt() ?? 0,
      accountStatus: isActive
          ? AdminAccountStatus.active
          : AdminAccountStatus.deactivated,
      role: AdminUserRoleX.fromValue(row['role'] as String?),
      phone: row['phone_number'] as String? ?? '',
      joinedAt: createdAt == null ? null : DateTime.tryParse(createdAt),
    );
  }

  AdminAuditLog _auditLogFromRow(Map<String, dynamic> row) {
    final rawChanges =
        row['field_changes'] as Map<String, dynamic>? ?? const {};
    return AdminAuditLog(
      id: '${row['id']}',
      adminUsername: _stringOrEmpty(row['admin_username']),
      action: _stringOrEmpty(row['action']),
      targetUsername: _stringOrEmpty(row['target_username']),
      fieldChanges: {
        for (final entry in rawChanges.entries)
          if (entry.value is Map)
            entry.key: AdminAuditFieldChange(
              from: _stringOrEmpty((entry.value as Map)['from']),
              to: _stringOrEmpty((entry.value as Map)['to']),
            ),
      },
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Future<Map<String, String>> _loadPrimaryImages(
    Iterable<dynamic> restaurantIds,
  ) async {
    final ids = restaurantIds.whereType<num>().toList(growable: false);
    if (ids.isEmpty) return const {};

    // Images are helpful in the catalogue, but a missing image table or a
    // permissions issue must never prevent the restaurant records themselves
    // from rendering.
    try {
      final rows = await _client
          .from('restaurant_images')
          .select('restaurant_id, image_url, is_primary')
          .inFilter('restaurant_id', ids);
      final imageUrls = <String, String>{};
      for (final row in rows) {
        final restaurantId = row['restaurant_id'];
        final imageUrl = row['image_url']?.toString() ?? '';
        if (restaurantId == null || imageUrl.isEmpty) continue;
        final key = '$restaurantId';
        if (row['is_primary'] == true || !imageUrls.containsKey(key)) {
          imageUrls[key] = imageUrl;
        }
      }
      return imageUrls;
    } on Object {
      return const {};
    }
  }

  Future<void> _persistPrimaryImage(
    dynamic restaurantId,
    String imageUrl,
  ) async {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) return;

    final existing = await _client
        .from('restaurant_images')
        .select('id, image_url')
        .eq('restaurant_id', restaurantId)
        .eq('is_primary', true)
        .limit(1);
    if (existing.isEmpty) {
      await _client.from('restaurant_images').insert({
        'restaurant_id': restaurantId,
        'image_url': trimmedUrl,
        'is_primary': true,
      });
      return;
    }
    if (_stringOrEmpty(existing.first['image_url']) == trimmedUrl) return;
    await _client
        .from('restaurant_images')
        .update({'image_url': trimmedUrl})
        .eq('id', existing.first['id']);
  }

  AdminRestaurant _restaurantFromRow(
    Map<String, dynamic> row, {
    String? primaryImageUrl,
  }) {
    final hours = row['operating_hours'] ?? row['business_hours'];
    String operatingHours;
    if (hours is Map) {
      operatingHours = hours.values
          .map((value) => value?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .join(', ');
    } else {
      operatingHours = hours?.toString() ?? '';
    }

    return AdminRestaurant(
      id: '${row['id']}',
      name: _stringOrEmpty(row['name']),
      cuisine: _cuisineFromRow(row),
      address: _addressFromRow(row),
      imageUrl: primaryImageUrl ?? _primaryImageFromEmbeddedRow(row),
      operatingHours: operatingHours,
      contact: _stringOrEmpty(row['phone_number'] ?? row['phone']),
      ownerName: _stringOrEmpty(row['owner_name']),
      budget: _budgetFromRow(row['price_range']),
      description: row['description'] as String? ?? '',
      sourcePlatform: _sourcePlatformFromRow(row),
      isVerified:
          row['is_approved'] as bool? ??
          ((row['verification_confidence'] as num?)?.toDouble() ?? 0) >= 0.8,
      rating: (row['rating'] as num?)?.toDouble(),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }

  String _cuisineFromRow(Map<String, dynamic> row) {
    final rawCategories = row['categories'];
    if (rawCategories is List) {
      return rawCategories
          .map(
            (category) => category is Map
                ? category['name']?.toString() ?? ''
                : category?.toString() ?? '',
          )
          .where((name) => name.isNotEmpty)
          .join(', ');
    }
    final relationships = row['restaurant_categories'];
    if (relationships is! List) return '';
    return relationships
        .map((relationship) {
          final category = relationship is Map
              ? relationship['categories']
              : null;
          return category is Map ? category['name']?.toString() ?? '' : '';
        })
        .where((name) => name.isNotEmpty)
        .join(', ');
  }

  String _primaryImageFromEmbeddedRow(Map<String, dynamic> row) {
    final images = row['restaurant_images'];
    if (images is! List) return '';
    var fallback = '';
    for (final image in images) {
      if (image is! Map) continue;
      final url = image['image_url']?.toString() ?? '';
      if (url.isEmpty) continue;
      fallback = fallback.isEmpty ? url : fallback;
      if (image['is_primary'] == true) return url;
    }
    return fallback;
  }

  String _addressFromRow(Map<String, dynamic> row) {
    final address = _stringOrEmpty(row['address']);
    if (address.isNotEmpty) return address;
    return [
      row['city'],
      row['state'],
    ].map(_stringOrEmpty).where((part) => part.isNotEmpty).join(', ');
  }

  String _budgetFromRow(dynamic value) {
    final priceRange = _stringOrEmpty(value);
    return switch (priceRange) {
      r'$' || '0' || '1' => 'Low',
      r'$$' || '2' => 'Medium',
      r'$$$' || r'$$$$' || '3' || '4' => 'High',
      _ => priceRange,
    };
  }

  String _sourcePlatformFromRow(Map<String, dynamic> row) {
    final source = _stringOrEmpty(row['social_media_source']);
    if (source.isNotEmpty) return source;
    if (_stringOrEmpty(row['instagram_username']).isNotEmpty) {
      return 'Instagram';
    }
    return 'Manual';
  }

  Map<String, Object?> _currentRestaurantPayload(
    AdminRestaurantDraft draft,
    Set<String>? changedFields,
  ) {
    bool changed(String field) =>
        changedFields == null || changedFields.contains(field);

    return {
      if (changed('name')) 'name': draft.name.trim(),
      if (changed('name'))
        'normalized_name': _normalizeRestaurantName(draft.name),
      if (changed('description'))
        'description': _nullWhenBlank(draft.description),
      if (changed('address')) 'address': draft.address.trim(),
      if (changed('latitude')) 'latitude': draft.latitude,
      if (changed('longitude')) 'longitude': draft.longitude,
      if (changed('contact')) 'phone': _nullWhenBlank(draft.contact),
      if (changed('owner_name')) 'owner_name': _nullWhenBlank(draft.ownerName),
      if (changed('budget')) 'price_range': _currentPriceRange(draft.budget),
      if (changed('rating')) 'rating': draft.rating,
      if (changed('cuisine')) 'categories': _categoryValues(draft.cuisine),
      if (changed('operating_hours'))
        'business_hours': {'status': draft.operatingHours.trim()},
      if (changed('source_platform'))
        'social_media_source': _nullWhenBlank(draft.sourcePlatform),
      if (changed('verification_status'))
        'verification_confidence': draft.isVerified ? 0.9 : 0.0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _legacyRestaurantPayload(
    AdminRestaurantDraft draft,
    Set<String>? changedFields,
  ) {
    bool changed(String field) =>
        changedFields == null || changedFields.contains(field);

    return {
      if (changed('name')) 'name': draft.name.trim(),
      if (changed('description'))
        'description': _nullWhenBlank(draft.description),
      if (changed('address')) 'address': draft.address.trim(),
      if (changed('latitude') && draft.latitude != null)
        'latitude': draft.latitude,
      if (changed('longitude') && draft.longitude != null)
        'longitude': draft.longitude,
      if (changed('contact')) 'phone_number': _nullWhenBlank(draft.contact),
      if (changed('owner_name')) 'owner_name': _nullWhenBlank(draft.ownerName),
      if (changed('budget')) 'price_range': _legacyPriceRange(draft.budget),
      if (changed('rating')) 'rating': draft.rating,
      if (changed('operating_hours'))
        'operating_hours': {'status': draft.operatingHours.trim()},
      if (changed('source_platform'))
        'social_media_source': _nullWhenBlank(draft.sourcePlatform),
      if (changed('verification_status')) 'is_approved': draft.isVerified,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    };
  }

  List<String> _categoryValues(String cuisine) => cuisine
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  String _currentPriceRange(String budget) => switch (budget) {
    'Low' => '1',
    'Medium' => '2',
    'High' => '3',
    _ => budget,
  };

  String _legacyPriceRange(String budget) => switch (budget) {
    'Low' => r'$',
    'Medium' => r'$$',
    'High' => r'$$$',
    _ => budget,
  };

  String? _nullWhenBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeRestaurantName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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
              user:users!comments_user_id_fkey(username)
            ''')
        .eq('id', commentId)
        .maybeSingle();
    if (row == null) return null;

    final user = row['user'] as Map<String, dynamic>?;
    return ReportedContent(
      username: _stringOrEmpty(user?['username']),
      text: row['content'] as String? ?? '',
      mediaUrls: const [],
    );
  }

  Future<bool> _contentIsPost(String contentId) async {
    final id = int.parse(contentId);
    final post = await _client
        .from('posts')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    if (post != null) return true;
    // Hidden posts are filtered from non-admin sessions; fall back to the
    // comments table before assuming the content is a comment.
    final comment = await _client
        .from('comments')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    return comment == null;
  }

  String _stringOrEmpty(dynamic value) => value?.toString() ?? '';

  bool _isMissingColumn(PostgrestException error) =>
      error.code == '42703' ||
      error.code == 'PGRST204' ||
      error.message.contains('Could not find') &&
          error.message.contains('column');
}
