import 'dart:typed_data';

/// Fallback avatar used when a profile has not uploaded a picture yet.
const defaultProfileAsset = 'assets/images/default_icon.jpg';

class CustomerProfile {
  const CustomerProfile({
    required this.username,
    required this.email,
    required this.bio,
    required this.profileAsset,
    required this.profileTitle,
    required this.role,
    required this.accountStatus,
    required this.communityScore,
  });

  final String username;
  final String email;
  final String bio;

  /// The avatar to display: either a network URL (uploaded avatar) or a
  /// bundled asset path (fallback picture).
  final String profileAsset;
  final String profileTitle;
  final String role;
  final String accountStatus;
  final int communityScore;

  /// True when [profileAsset] points at a hosted (network) image rather than
  /// a bundled asset, so screens can pick `Image.network` over `Image.asset`.
  bool get usesNetworkImage => profileAsset.startsWith('http');

  CustomerProfile copyWith({
    String? username,
    String? bio,
    String? profileAsset,
  }) {
    return CustomerProfile(
      username: username ?? this.username,
      email: email,
      bio: bio ?? this.bio,
      profileAsset: profileAsset ?? this.profileAsset,
      profileTitle: profileTitle,
      role: role,
      accountStatus: accountStatus,
      communityScore: communityScore,
    );
  }
}

/// A profile picture the user picked for upload, decoded outside the
/// repository so UI and repository stay free of direct `dart:io` access.
class ProfilePictureUpload {
  const ProfilePictureUpload({
    required this.bytes,
    required this.mimeType,
    this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;

  /// Original file name, used to keep a readable extension on the object.
  /// Null-safe by falling back to a generic name when uploading.
  final String? fileName;
}

class ProfileData {
  const ProfileData({
    required this.profile,
    required this.visits,
    required this.reviews,
    required this.cuisines,
    required this.earnedBadges,
  });

  final CustomerProfile profile;
  final int visits;
  final int reviews;
  final int cuisines;
  final List<String> earnedBadges;
}