import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_models.dart';
import 'fixture_admin_repository.dart';

/// Shared override point for the administrator console data source.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
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

  Future<List<ModerationReport>> loadReports();

  Future<ModerationReport?> loadReport(String id);

  Future<ReportedContent?> loadReportedContent(ModerationReport report);

  Future<ModerationReport?> resolveReport({
    required String id,
    required ReportStatus status,
    String? removalReason,
  });
}
