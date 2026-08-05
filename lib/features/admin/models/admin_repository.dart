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
  Future<AdminDashboardData> loadDashboard();

  Future<List<AdminUser>> loadUsers();

  Future<AdminUser?> loadUser(String id);

  Future<AdminUser?> updateUser({
    required String id,
    required String username,
    required String profileTitle,
    required int communityScore,
  });

  Future<AdminUser?> setUserAccountStatus(String id, AdminAccountStatus status);

  Future<List<AdminRestaurant>> loadRestaurants();

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
  Future<ReportedContentGroup?> loadReportedContentGroup(String contentId);

  /// Returns the full content (post or comment) for a reported content group.
  Future<ReportedContent?> loadReportedContent(ReportedContentGroup group);

  /// Hides the content from public view (soft-delete via is_hidden).
  Future<void> removeContent(String contentId);

  /// Soft-deletes all reports for the given content (content stays visible).
  Future<void> dismissReports(String contentId);
}
