class UserProgress {
  const UserProgress({
    required this.earnedBadgeIds,
    required this.communityScore,
    required this.profileTitle,
  });

  final List<String> earnedBadgeIds;
  final int communityScore;
  final String profileTitle;
}
