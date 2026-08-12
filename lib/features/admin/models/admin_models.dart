/// Typed models for the MakanSpot administrator console.
library;

enum AdminAccountStatus { active, deactivated }

enum AdminUserRole { user, admin }

extension AdminUserRoleX on AdminUserRole {
  String get label => this == AdminUserRole.admin ? 'Admin' : 'User';

  String get value => this == AdminUserRole.admin ? 'admin' : 'user';

  static AdminUserRole fromValue(String? value) {
    return value == 'admin' ? AdminUserRole.admin : AdminUserRole.user;
  }
}

enum ReportContentType { post, comment }

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.profilePictureUrl,
    required this.profileTitle,
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
  final String profileTitle;
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
    String? profileTitle,
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
      profileTitle: profileTitle ?? this.profileTitle,
      communityScore: communityScore ?? this.communityScore,
      accountStatus: accountStatus ?? this.accountStatus,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      joinedAt: joinedAt,
    );
  }
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
  final String budget;
  final String description;
  final String sourcePlatform;
  final bool isVerified;
  final double? rating;
  final double? latitude;
  final double? longitude;

  String get ratingDisplay {
    final value = rating;
    if (value == null) return '—';
    return value.toStringAsFixed(1);
  }
}

class AdminRestaurantDraft {
  const AdminRestaurantDraft({
    required this.name,
    required this.cuisine,
    required this.address,
    required this.operatingHours,
    required this.contact,
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
