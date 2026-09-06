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

  // ── Users ────────────────────────────────────────────────────────

  @override
  Future<List<AdminUser>> loadUsers() async {
    final rows = await _client.from('users').select().order('username');
    return rows.map(_userFromRow).toList(growable: false);
  }

  @override
  Future<AdminUserPage> loadUsersPage({
    required UserStatusFilter statusFilter,
    required UserRoleFilter roleFilter,
    String? search,
    required int limit,
    required int offset,
  }) async {
    // NOTE: postgrest 2.8.0 builders are immutable — every filter/transform
    // returns a NEW builder, so the result must be reassigned. Calling
    // `query.ilike(...)` as a statement silently discards the filter and the
    // request goes out as a bare select (no search, filter, or paging).
    var query = _client.from('users').select();

    final text = search?.trim() ?? '';
    if (text.isNotEmpty) {
      // Escape LIKE wildcards so user input is matched literally, and strip
      // characters that would break the or() filter syntax.
      final term = text
          .replaceAll(RegExp(r'[,()]'), ' ')
          .replaceAll('\\', '\\\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      query = query.or('username.ilike.%$term%,email.ilike.%$term%');
    }

    if (statusFilter == UserStatusFilter.active) {
      query = query.eq('is_active', true);
    } else if (statusFilter == UserStatusFilter.deactivated) {
      query = query.eq('is_active', false);
    }

    if (roleFilter != UserRoleFilter.all) {
      query = query.eq('role', roleFilter.name);
    }

    // Request one extra row so hasMore is exact: no false "more" when
    // the last page happens to be exactly full, and no extra request
    // for an empty page after the final one.
    final rows = await query
        .order('username', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit);

    final pageRows = rows.length > limit ? rows.sublist(0, limit) : rows;
    return AdminUserPage(
      items: pageRows.map(_userFromRow).toList(growable: false),
      hasMore: rows.length > limit,
    );
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
  Future<void> logAdminAction({
    required String adminUserId,
    required String adminUsername,
    required String action,
    required String targetUserId,
    required String targetUsername,
    Map<String, Map<String, Object?>>? fieldChanges,
  }) async {
    await _client.from('admin_audit_log').insert({
      'admin_user_id': adminUserId,
      'admin_username': adminUsername,
      'action': action,
      'target_user_id': targetUserId,
      'target_username': targetUsername,
      'field_changes': fieldChanges ?? {},
    });
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
  Future<AdminRestaurantPage> loadRestaurants({
    required RestaurantStatusFilter statusFilter,
    required RestaurantSort sort,
    String? search,
    required int limit,
    required int offset,
  }) async {
    // NOTE: postgrest 2.8.0 builders are immutable — every filter/transform
    // returns a NEW builder, so the result must be reassigned. Calling
    // `query.ilike(...)` as a statement silently discards the filter and the
    // request goes out as a bare select (no search, filter, sort, or paging).
    var query = _client.from('restaurants').select('''
              id,
              name,
              description,
              address,
              city,
              state,
              latitude,
              longitude,
              price_range,
              phone,
              website,
              instagram_username,
              instagram_location_id,
              categories,
              business_hours,
              verification_confidence,
              source_post_count,
              popularity_score,
              created_at,
              updated_at,
              deleted_at,
              restaurant_images(image_url, is_primary)
            ''');

    final text = search?.trim() ?? '';
    if (text.isNotEmpty) {
      // Escape LIKE wildcards so user input is matched literally, and strip
      // characters that would break the or() filter syntax.
      final term = text
          .replaceAll(RegExp(r'[,()]'), ' ')
          .replaceAll('\\', '\\\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      query = query.or(
        'name.ilike.%$term%,'
        'address.ilike.%$term%,'
        'city.ilike.%$term%,'
        'state.ilike.%$term%,'
        'description.ilike.%$term%',
      );
    }

    if (statusFilter == RestaurantStatusFilter.active) {
      query = query.isFilter('deleted_at', null);
    } else if (statusFilter == RestaurantStatusFilter.deleted) {
      query = query.not('deleted_at', 'is', null);
    }

    final ascending = sort == RestaurantSort.nameAscending;
    // Request one extra row so hasMore is exact: no false "more" when
    // the last page happens to be exactly full, and no extra request
    // for an empty page after the final one.
    final rows = await query
        .order('name', ascending: ascending)
        .order('id', ascending: true)
        .range(offset, offset + limit);

    final pageRows = rows.length > limit ? rows.sublist(0, limit) : rows;
    return AdminRestaurantPage(
      items: pageRows.map(_restaurantFromRow).toList(growable: false),
      hasMore: rows.length > limit,
    );
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
              city,
              state,
              latitude,
              longitude,
              price_range,
              phone,
              website,
              instagram_username,
              instagram_location_id,
              categories,
              business_hours,
              verification_confidence,
              source_post_count,
              popularity_score,
              created_at,
              updated_at,
              deleted_at,
              restaurant_images(image_url, is_primary)
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
  ) async {
    final didUpdate = await _client.rpc(
      'admin_update_restaurant',
      params: {
        'p_restaurant_id': int.parse(id),
        'p_name': draft.name,
        'p_normalized_name': _normalizeRestaurantName(draft.name),
        'p_description': _nullIfBlank(draft.description),
        'p_address': _nullIfBlank(draft.address),
        'p_city': _nullIfBlank(draft.city),
        'p_state': _nullIfBlank(draft.state),
        'p_latitude': draft.latitude,
        'p_longitude': draft.longitude,
        'p_phone': _nullIfBlank(draft.phone),
        'p_website': _nullIfBlank(draft.website),
        'p_price_range': _nullIfBlank(draft.priceRange),
        'p_instagram_username': _nullIfBlank(draft.instagramUsername),
        'p_categories': draft.categories,
        'p_business_hours': draft.businessHours,
        'p_image_url': _nullIfBlank(draft.imageUrl),
      },
    );

    if (didUpdate != true) {
      return null;
    }
    return loadRestaurant(id);
  }

  @override
  Future<bool> restaurantExists(
    AdminRestaurantDraft draft,
    String excludeRestaurantId,
  ) async {
    final rows = await _client
        .from('restaurants')
        .select(
          'id, name, address, city, state, latitude, longitude, phone, '
          'website, instagram_username',
        )
        .neq('id', int.parse(excludeRestaurantId));
    return rows.any(
      (row) => _matchesRestaurantIdentity(
        row as Map<String, dynamic>,
        draft,
      ),
    );
  }

  @override
  Future<void> deleteRestaurant(
    String id, {
    required RestaurantRemovalReason reason,
    String? additionalNote,
  }) async {
    await _client.rpc(
      'admin_remove_restaurant',
      params: {
        'p_restaurant_id': int.parse(id),
        'p_reason': reason.label,
        'p_additional_note': _nullIfBlank(additionalNote ?? ''),
      },
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

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeRestaurantName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matchesRestaurantIdentity(
    Map<String, dynamic> restaurant,
    AdminRestaurantDraft draft,
  ) {
    final proposedName = _normalizeRestaurantName(draft.name);
    if (proposedName.isNotEmpty &&
        _normalizeRestaurantName(_stringOrEmpty(restaurant['name'])) ==
            proposedName) {
      return true;
    }

    final proposedPhone = _nullIfBlank(draft.phone);
    if (proposedPhone != null &&
        _stringOrEmpty(restaurant['phone']).trim() == proposedPhone) {
      return true;
    }

    final proposedWebsite = _nullIfBlank(draft.website);
    if (proposedWebsite != null &&
        _stringOrEmpty(restaurant['website']).trim().toLowerCase() ==
            proposedWebsite.toLowerCase()) {
      return true;
    }

    final proposedInstagram = _nullIfBlank(draft.instagramUsername);
    if (proposedInstagram != null &&
        _stringOrEmpty(restaurant['instagram_username']).trim().toLowerCase() ==
            proposedInstagram.toLowerCase()) {
      return true;
    }

    final proposedAddress = _nullIfBlank(draft.address);
    if (proposedAddress != null &&
        _normalizedIdentityValue(restaurant['address']) ==
            _normalizedIdentityValue(proposedAddress) &&
        _normalizedIdentityValue(restaurant['city']) ==
            _normalizedIdentityValue(draft.city) &&
        _normalizedIdentityValue(restaurant['state']) ==
            _normalizedIdentityValue(draft.state)) {
      return true;
    }

    final latitude = restaurant['latitude'] as num?;
    final longitude = restaurant['longitude'] as num?;
    return draft.latitude != null &&
        draft.longitude != null &&
        latitude?.toDouble() == draft.latitude &&
        longitude?.toDouble() == draft.longitude;
  }

  String _normalizedIdentityValue(Object? value) {
    return _stringOrEmpty(value).trim().toLowerCase();
  }

  AdminRestaurant _restaurantFromRow(Map<String, dynamic> row) {
    final images = row['restaurant_images'] as List<dynamic>?;
    final primaryImage = images?.cast<Map<String, dynamic>>().firstWhere(
      (img) => img['is_primary'] == true,
      orElse: () => {'image_url': ''},
    );
    final imageUrl = primaryImage?['image_url'] as String? ?? '';

    final categoriesRaw = row['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.cast<String>()
        : <String>[];

    final businessHoursRaw = row['business_hours'];
    final businessHours = businessHoursRaw is Map<String, dynamic>
        ? businessHoursRaw
        : null;

    return AdminRestaurant(
      id: '${row['id']}',
      name: _stringOrEmpty(row['name']),
      categories: categories,
      imageUrl: imageUrl,
      description: row['description'] as String?,
      address: row['address'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      phone: row['phone'] as String?,
      website: row['website'] as String?,
      priceRange: row['price_range'] as String?,
      businessHours: businessHours,
      instagramUsername: row['instagram_username'] as String?,
      instagramLocationId: row['instagram_location_id'] as String?,
      verificationConfidence: (row['verification_confidence'] as num?)
          ?.toDouble(),
      sourcePostCount: row['source_post_count'] as int?,
      popularityScore: row['popularity_score'] as int?,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.tryParse(row['deleted_at'].toString()),
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
}
