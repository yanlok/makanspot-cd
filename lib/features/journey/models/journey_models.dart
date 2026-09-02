class JourneyUser {
  const JourneyUser({
    required this.username,
    required this.email,
    required this.profileTitle,
    required this.communityScore,
    required this.profileAsset,
  });

  final String username;
  final String email;
  final String profileTitle;
  final int communityScore;
  final String profileAsset;

  JourneyUser copyWith({int? communityScore}) {
    return JourneyUser(
      username: username,
      email: email,
      profileTitle: profileTitle,
      communityScore: communityScore ?? this.communityScore,
      profileAsset: profileAsset,
    );
  }
}

class JourneyVisit {
  const JourneyVisit({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImage,
    required this.cuisine,
    required this.visitDate,
    required this.postId,
  });

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String cuisine;
  final DateTime visitDate;
  final String? postId;
}

class JourneyLocation {
  const JourneyLocation({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.imageUrl,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String cuisine;
  final String imageUrl;
  final String address;
  final double latitude;
  final double longitude;
}

class JourneyAchievement {
  const JourneyAchievement({
    required this.name,
    required this.description,
    required this.category,
    required this.requirement,
    required this.points,
    required this.iconName,
  });

  final String name;
  final String description;
  final String category;
  final int requirement;
  final int points;
  final String iconName;
}

class JourneyAchievementProgress {
  const JourneyAchievementProgress({
    required this.achievement,
    required this.progress,
  });

  final JourneyAchievement achievement;
  final int progress;
  bool get earned => progress >= achievement.requirement;
}

class JourneyScoreActivity {
  const JourneyScoreActivity({
    required this.description,
    required this.points,
    required this.date,
    required this.isReview,
  });

  final String description;
  final int points;
  final DateTime date;
  final bool isReview;
}

class JourneyData {
  const JourneyData({
    required this.user,
    required this.visits,
    required this.locations,
    required this.reviewCount,
    required this.totalLikes,
    required this.achievements,
    required this.scoreHistory,
  });

  final JourneyUser user;
  final List<JourneyVisit> visits;
  final List<JourneyLocation> locations;
  final int reviewCount;
  final int totalLikes;
  final List<JourneyAchievement> achievements;
  final List<JourneyScoreActivity> scoreHistory;

  JourneyData copyWith({
    JourneyUser? user,
    List<JourneyVisit>? visits,
    int? reviewCount,
    List<JourneyScoreActivity>? scoreHistory,
  }) {
    return JourneyData(
      user: user ?? this.user,
      visits: visits ?? this.visits,
      locations: locations,
      reviewCount: reviewCount ?? this.reviewCount,
      totalLikes: totalLikes,
      achievements: achievements,
      scoreHistory: scoreHistory ?? this.scoreHistory,
    );
  }

  int get cuisineCount => visits.map((visit) => visit.cuisine).toSet().length;

  List<JourneyAchievementProgress> get achievementProgress {
    return achievements
        .map((achievement) {
          final progress = switch (achievement.category) {
            'visits' => visits.length,
            'reviews' => reviewCount,
            'cuisines' => cuisineCount,
            'social' => totalLikes,
            _ => 1,
          };
          return JourneyAchievementProgress(
            achievement: achievement,
            progress: progress,
          );
        })
        .toList(growable: false);
  }
}
