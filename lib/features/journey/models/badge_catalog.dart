import 'badge.dart';
import 'journey_models.dart';

const journeyBadgeCatalog = <Badge>[
  Badge(
    id: 'first-bite',
    name: 'First Bite',
    description: 'Visit your first restaurant',
    requirement: 'Visit 1 restaurant',
    requirementType: 'restaurants_visited',
    requirementValue: 1,
    iconName: 'utensils',
    points: 10,
  ),
  Badge(
    id: 'food-trail',
    name: 'Food Trail',
    description: 'Visit 5 different restaurants',
    requirement: 'Visit 5 restaurants',
    requirementType: 'restaurants_visited',
    requirementValue: 5,
    iconName: 'mapPin',
    points: 30,
  ),
  Badge(
    id: 'makan-champion',
    name: 'Makan Champion',
    description: 'Visit 20 restaurants',
    requirement: 'Visit 20 restaurants',
    requirementType: 'restaurants_visited',
    requirementValue: 20,
    iconName: 'trophy',
    points: 100,
  ),
  Badge(
    id: 'review-rookie',
    name: 'Review Rookie',
    description: 'Write your first review',
    requirement: 'Write 1 review',
    requirementType: 'reviews_submitted',
    requirementValue: 1,
    iconName: 'penLine',
    points: 10,
  ),
  Badge(
    id: 'review-regular',
    name: 'Review Regular',
    description: 'Write 10 reviews',
    requirement: 'Write 10 reviews',
    requirementType: 'reviews_submitted',
    requirementValue: 10,
    iconName: 'star',
    points: 50,
  ),
  Badge(
    id: 'cuisine-explorer',
    name: 'Cuisine Explorer',
    description: 'Try 3 different cuisines',
    requirement: 'Try 3 cuisines',
    requirementType: 'cuisines_explored',
    requirementValue: 3,
    iconName: 'compass',
    points: 30,
  ),
  Badge(
    id: 'community-voice',
    name: 'Community Voice',
    description: 'Get 50 total likes on your posts',
    requirement: 'Receive 50 likes',
    requirementType: 'likes_received',
    requirementValue: 50,
    iconName: 'heart',
    points: 50,
  ),
  Badge(
    id: 'trendsetter',
    name: 'Trendsetter',
    description: 'Get 100 total likes on your posts',
    requirement: 'Receive 100 likes',
    requirementType: 'likes_received',
    requirementValue: 100,
    iconName: 'flame',
    points: 100,
  ),
];

List<JourneyAchievement> journeyAchievementsFromCatalog() {
  return journeyBadgeCatalog
      .map(
        (badge) => JourneyAchievement(
          name: badge.name,
          description: badge.description,
          category: switch (badge.requirementType) {
            'restaurants_visited' => 'visits',
            'reviews_submitted' => 'reviews',
            'cuisines_explored' => 'cuisines',
            'likes_received' => 'social',
            _ => 'milestone',
          },
          requirement: badge.requirementValue,
          points: badge.points,
          iconName: badge.iconName ?? 'award',
        ),
      )
      .toList(growable: false);
}
