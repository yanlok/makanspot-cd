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
  final String profileAsset;
  final String profileTitle;
  final String role;
  final String accountStatus;
  final int communityScore;

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

enum AccountRoleFilter { all, user, admin }

enum AccountStatusFilter { all, active, pending, deactivated }

class DemoRegisteredAccount {
  const DemoRegisteredAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.bio,
    required this.photoUrl,
    required this.role,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final String bio;
  final String photoUrl;
  final String role;
  final String status;

  String get initial {
    if (name.isEmpty) {
      return 'U';
    }
    return name.substring(0, 1).toUpperCase();
  }
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
