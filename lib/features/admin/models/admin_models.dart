/// Typed models for the MakanSpot administrator console.
library;

enum AdminAccountStatus { active, deactivated }

enum ReportStatus { pending, removed, dismissed }

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
  });

  final String id;
  final String username;
  final String email;
  final String profilePictureUrl;
  final String profileTitle;
  final int communityScore;
  final AdminAccountStatus accountStatus;

  String get initial {
    if (username.isEmpty) {
      return 'U';
    }
    return username.substring(0, 1).toUpperCase();
  }

  AdminUser copyWith({
    String? username,
    String? profileTitle,
    int? communityScore,
    AdminAccountStatus? accountStatus,
  }) {
    return AdminUser(
      id: id,
      username: username ?? this.username,
      email: email,
      profilePictureUrl: profilePictureUrl,
      profileTitle: profileTitle ?? this.profileTitle,
      communityScore: communityScore ?? this.communityScore,
      accountStatus: accountStatus ?? this.accountStatus,
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
    if (value == null) {
      return '—';
    }
    return value.toStringAsFixed(1);
  }
}

/// Editable restaurant values captured by the restaurant form.
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

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.contentPreview,
    required this.contentOwner,
    required this.reporterName,
    required this.reason,
    required this.status,
    required this.reportCount,
    required this.createdDate,
    this.additionalInfo,
    this.removalReason,
  });

  final String id;
  final ReportContentType contentType;
  final String contentId;
  final String contentPreview;
  final String contentOwner;
  final String reporterName;
  final String reason;
  final ReportStatus status;
  final int reportCount;
  final DateTime createdDate;
  final String? additionalInfo;
  final String? removalReason;

  bool get isResolved =>
      status == ReportStatus.removed || status == ReportStatus.dismissed;

  ModerationReport copyWith({ReportStatus? status, String? removalReason}) {
    return ModerationReport(
      id: id,
      contentType: contentType,
      contentId: contentId,
      contentPreview: contentPreview,
      contentOwner: contentOwner,
      reporterName: reporterName,
      reason: reason,
      status: status ?? this.status,
      reportCount: reportCount,
      createdDate: createdDate,
      additionalInfo: additionalInfo,
      removalReason: removalReason ?? this.removalReason,
    );
  }
}

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
  final List<ModerationReport> recentReports;
}
