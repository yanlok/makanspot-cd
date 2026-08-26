import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/core/config/supabase_config.dart';

import 'admin_models.dart';
import 'fixture_admin_repository.dart';
import 'supabase_admin_repository.dart';

/// Shared override point for the administrator console data source.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAdminRepository(Supabase.instance.client);
  }
  return FixtureAdminRepository();
});

/// Data-source boundary for the MakanSpot administrator console.
abstract interface class AdminRepository {
  /// Whether restaurant updates are written to the admin audit trail by the
  /// same database transaction that persists the restaurant.
  bool get restaurantUpdatesAreAutomaticallyAudited;

  Future<AdminDashboardData> loadDashboard();

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

  /// True when another restaurant already holds [name]. When updating an
  /// existing record, pass its ID in [excludeRestaurantId].
  Future<bool> restaurantNameExists(String name, {String? excludeRestaurantId});

  /// Records an audit-trail entry for an administrative action.
  Future<void> logAdminAction({
    required String adminUserId,
    required String adminUsername,
    required String action,
    String? targetUserId,
    required String targetUsername,
    Map<String, Map<String, Object?>>? fieldChanges,
  });

  /// Returns administrative actions in reverse chronological order.
  Future<List<AdminAuditLog>> loadAdminActionLogs();

  Future<List<AdminRestaurant>> loadRestaurants();

  Future<AdminRestaurant?> loadRestaurant(String id);

  Future<AdminRestaurant> createRestaurant(AdminRestaurantDraft draft);

  Future<AdminRestaurant?> updateRestaurant(
    String id,
    AdminRestaurantDraft draft, {
    Set<String>? changedFields,
  });

  Future<void> deleteRestaurant(String id);

  /// Returns all reported content grouped by post or comment.
  Future<List<ReportedContentGroup>> loadReportedContentGroups();

  /// Returns a single reported content group by its content ID.
  Future<ReportedContentGroup?> loadReportedContentGroup(String contentId);

  /// Returns the full content (post or comment) for a reported content group.
  Future<ReportedContent?> loadReportedContent(ReportedContentGroup group);

  /// Hides the content from public view (soft-delete via is_hidden).
  Future<void> removeContent(String contentId);

  /// Soft-deletes all reports for the given content (content stays visible).
  Future<void> dismissReports(String contentId);
}

/// Raised when an update request completes without changing a visible row.
///
/// With row-level security this can mean either that the record disappeared
/// or that the signed-in account is no longer allowed to update it.
class RestaurantUpdateNoRowsException implements Exception {
  const RestaurantUpdateNoRowsException();
}
