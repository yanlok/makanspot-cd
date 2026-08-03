class CustomerProfile {
  const CustomerProfile({
    required this.username,
    required this.email,
    required this.bio,
    required this.profileAsset,
    required this.profileTitle,
    required this.communityScore,
  });

  final String username;
  final String email;
  final String bio;
  final String profileAsset;
  final String profileTitle;
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
      communityScore: communityScore,
    );
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
