/// Typed models for the MakanSpot administrator console.
library;

enum AdminAccountStatus { active, deactivated }

enum AdminUserRole { user, admin, manager }

extension AdminUserRoleX on AdminUserRole {
  String get label => switch (this) {
    AdminUserRole.user => 'User',
    AdminUserRole.admin => 'Admin',
    AdminUserRole.manager => 'Manager',
  };

  String get value => switch (this) {
    AdminUserRole.user => 'user',
    AdminUserRole.admin => 'admin',
    AdminUserRole.manager => 'manager',
  };

  static AdminUserRole fromValue(String? value) {
    return switch (value) {
      'admin' => AdminUserRole.admin,
      'manager' => AdminUserRole.manager,
      _ => AdminUserRole.user,
    };
  }

  String get accountIdPrefix => switch (this) {
    AdminUserRole.user => 'U',
    AdminUserRole.admin => 'A',
    AdminUserRole.manager => 'M',
  };
}

enum ReportContentType { post, comment }

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.profilePictureUrl,
    required this.communityScore,
    required this.accountStatus,
    this.role = AdminUserRole.user,
    this.phone = '',
    this.joinedAt,
  });

  final String id;
  final String username;
  final String email;
  final String profilePictureUrl;
  final int communityScore;
  final AdminAccountStatus accountStatus;
  final AdminUserRole role;
  final String phone;
  final DateTime? joinedAt;

  String get initial {
    if (username.isEmpty) return 'U';
    return username.substring(0, 1).toUpperCase();
  }

  AdminUser copyWith({
    String? username,
    String? email,
    int? communityScore,
    AdminAccountStatus? accountStatus,
    AdminUserRole? role,
    String? phone,
  }) {
    return AdminUser(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl,
      communityScore: communityScore ?? this.communityScore,
      accountStatus: accountStatus ?? this.accountStatus,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      joinedAt: joinedAt,
    );
  }
}

/// Creates a stable display ID from a user's role and alphabetical position.
String adminUserAccountId(AdminUser user, Iterable<AdminUser> allUsers) {
  final usersWithSameRole =
      allUsers.where((candidate) => candidate.role == user.role).toList()
        ..sort((left, right) {
          final nameComparison = left.username.toLowerCase().compareTo(
            right.username.toLowerCase(),
          );
          return nameComparison != 0
              ? nameComparison
              : left.id.compareTo(right.id);
        });
  final index = usersWithSameRole.indexWhere(
    (candidate) => candidate.id == user.id,
  );
  final position = index >= 0 ? index + 1 : usersWithSameRole.length + 1;
  return '${user.role.accountIdPrefix}${position.toString().padLeft(3, '0')}';
}

class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.adminUsername,
    required this.action,
    required this.targetUsername,
    required this.fieldChanges,
    required this.createdAt,
  });

  final String id;
  final String adminUsername;
  final String action;
  final String targetUsername;
  final Map<String, AdminAuditFieldChange> fieldChanges;
  final DateTime createdAt;
}

class AdminAuditFieldChange {
  const AdminAuditFieldChange({required this.from, required this.to});

  final String from;
  final String to;
}

class AdminRestaurant {
  const AdminRestaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.address,
    required this.imageUrl,
    required this.operatingHours,
    required this.contact,
    required this.ownerName,
    required this.budget,
    required this.description,
    required this.sourcePlatform,
    required this.isVerified,
    this.rating,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String cuisine;
  final String address;
  final String imageUrl;
  final String operatingHours;
  final String contact;
  final String ownerName;
  final String budget;
  final String description;
  final String sourcePlatform;
  final bool isVerified;
  final double? rating;
  final double? latitude;
  final double? longitude;

  String get verificationStatus => isVerified ? 'Verified' : 'Pending';

  String get ratingDisplay {
    final value = rating;
    if (value == null) return '—';
    return value.toStringAsFixed(1);
  }

  String get displayId {
    final numericId =
        int.tryParse(id) ??
        int.tryParse(RegExp(r'\d+$').firstMatch(id)?.group(0) ?? '');
    return numericId == null
        ? 'R$id'
        : 'R${numericId.toString().padLeft(5, '0')}';
  }
}

class AdminRestaurantDraft {
  const AdminRestaurantDraft({
    required this.name,
    required this.cuisine,
    required this.address,
    required this.operatingHours,
    required this.contact,
    required this.ownerName,
    required this.budget,
    required this.description,
    required this.imageUrl,
    required this.sourcePlatform,
    required this.isVerified,
    this.rating,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String cuisine;
  final String address;
  final String operatingHours;
  final String contact;
  final String ownerName;
  final String budget;
  final String description;
  final String imageUrl;
  final String sourcePlatform;
  final bool isVerified;
  final double? rating;
  final double? latitude;
  final double? longitude;
}

/// An individual report submitted by a single user.
class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reporterName,
    required this.reason,
    required this.createdDate,
    this.additionalInfo,
  });

  final String id;
  final String reporterName;
  final String reason;
  final DateTime createdDate;
  final String? additionalInfo;
}

/// A piece of content (post or comment) that has one or more reports.
///
/// [isRemoved] is derived from the content's `is_hidden` flag.
/// The overall status is: pending (has reports, visible) or removed (hidden).
class ReportedContentGroup {
  const ReportedContentGroup({
    required this.contentId,
    required this.contentType,
    required this.contentPreview,
    required this.contentOwner,
    required this.isRemoved,
    required this.reports,
  });

  final String contentId;
  final ReportContentType contentType;
  final String contentPreview;
  final String contentOwner;
  final bool isRemoved;
  final List<ModerationReport> reports;

  int get reportCount => reports.length;

  bool get isPending => !isRemoved;

  ReportedContentGroup copyWith({
    bool? isRemoved,
    List<ModerationReport>? reports,
  }) {
    return ReportedContentGroup(
      contentId: contentId,
      contentType: contentType,
      contentPreview: contentPreview,
      contentOwner: contentOwner,
      isRemoved: isRemoved ?? this.isRemoved,
      reports: reports ?? this.reports,
    );
  }
}

/// The full content (post or comment) displayed in the moderation details.
class ReportedContent {
  const ReportedContent({
    required this.username,
    required this.text,
    required this.mediaUrls,
    this.restaurantName,
  });

  final String username;
  final String? restaurantName;
  final String text;
  final List<String> mediaUrls;
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.userCount,
    required this.restaurantCount,
    required this.postCount,
    required this.commentCount,
    required this.pendingReportCount,
    required this.recentReports,
  });

  final int userCount;
  final int restaurantCount;
  final int postCount;
  final int commentCount;
  final int pendingReportCount;
  final List<ReportedContentGroup> recentReports;
}
