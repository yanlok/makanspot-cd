import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'supabase_admin_repository.dart';

/// Shared override point for the administrator console data source.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return SupabaseAdminRepository(Supabase.instance.client);
});

/// Data-source boundary for the MakanSpot administrator console.
abstract interface class AdminRepository {
  Future<List<AdminUser>> loadUsers();

  Future<AdminUser?> loadUser(String id);

  Future<AdminUser?> updateUser({
    required String id,
    required String username,
    required String email,
    required String phone,
    required AdminUserRole role,
    required int communityScore,
  });

  Future<AdminUser?> setUserAccountStatus(String id, AdminAccountStatus status);

  /// True when another user already holds [username] (excluding [excludeUserId]).
  Future<bool> usernameExists(String username, String excludeUserId);

  /// True when another user already holds [email] (excluding [excludeUserId]).
  Future<bool> emailExists(String email, String excludeUserId);

  /// True when another user already holds [phone] (excluding [excludeUserId]).
  Future<bool> phoneExists(String phone, String excludeUserId);

  /// Records an audit-trail entry for an administrative action.
  Future<void> logAdminAction({
    required String adminUserId,
    required String adminUsername,
    required String action,
    required String targetUserId,
    required String targetUsername,
    Map<String, Map<String, Object?>>? fieldChanges,
  });

  /// Returns administrative actions in reverse chronological order.
  Future<List<AdminAuditLog>> loadAdminActionLogs();

  Future<AdminRestaurantPage> loadRestaurants({
    required RestaurantStatusFilter statusFilter,
    required RestaurantSort sort,
    String? search,
    required int limit,
    required int offset,
  });

  Future<AdminRestaurant?> loadRestaurant(String id);

  Future<AdminRestaurant> createRestaurant(AdminRestaurantDraft draft);

  Future<AdminRestaurant?> updateRestaurant(
    String id,
    AdminRestaurantDraft draft,
  );

  Future<void> deleteRestaurant(String id);

  /// Returns all reported content grouped by post or comment.
  Future<List<ReportedContentGroup>> loadReportedContentGroups();

  /// Returns a single reported content group by its content ID.
  ///
  /// [contentType] is required because post and comment IDs come from
  /// separate auto-increment sequences, so the same numeric ID can refer
  /// to both a post and a comment.
  Future<ReportedContentGroup?> loadReportedContentGroup(
    String contentId,
    ReportContentType contentType,
  );

  /// Returns the full content (post or comment) for a reported content group.
  Future<ReportedContent?> loadReportedContent(ReportedContentGroup group);

  /// Hides the content from public view (soft-delete via is_hidden).
  Future<void> removeContent(String contentId, ReportContentType contentType);

  /// Soft-deletes all reports for the given content (content stays visible).
  Future<void> dismissReports(String contentId, ReportContentType contentType);
}
