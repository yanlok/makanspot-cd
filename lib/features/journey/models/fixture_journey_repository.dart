import 'journey_models.dart';
import 'journey_repository.dart';

class FixtureJourneyRepository implements JourneyRepository {
  const FixtureJourneyRepository();

  @override
  Future<JourneyData> loadJourney() async => _data;
}

String _image(String id) {
  return 'https://images.unsplash.com/$id?auto=format&fit=crop&w=900&q=80';
}

final _locations = <JourneyLocation>[
  JourneyLocation(
    id: 'rest-1',
    name: 'Nasi Lemak Wanjo',
    cuisine: 'Malaysian',
    imageUrl: _image('photo-1563379926898-05f4575a45d8'),
    address: '8, Jalan Raja Muda Musa, Kampung Baru, Kuala Lumpur',
    latitude: 3.1617,
    longitude: 101.7048,
  ),
  JourneyLocation(
    id: 'rest-2',
    name: 'Soong Kee Beef Noodles',
    cuisine: 'Chinese',
    imageUrl: _image('photo-1569718212165-3a8278d5f624'),
    address: '86, Jalan Tun H S Lee, Kuala Lumpur',
    latitude: 3.1459,
    longitude: 101.7003,
  ),
];

final _data = JourneyData(
  user: const JourneyUser(
    username: 'Yih Loong',
    email: 'yl@makanspot.my',
    profileTitle: 'Hidden Gem Hunter',
    communityScore: 185,
    profileAsset: 'assets/images/default_icon.jpg',
  ),
  visits: [
    JourneyVisit(
      id: 'visit-1',
      restaurantId: 'rest-1',
      restaurantName: 'Nasi Lemak Wanjo',
      restaurantImage: _image('photo-1563379926898-05f4575a45d8'),
      cuisine: 'Malaysian',
      visitDate: DateTime(2026, 7, 26),
      postId: 'post-1',
    ),
    JourneyVisit(
      id: 'visit-2',
      restaurantId: 'rest-2',
      restaurantName: 'Soong Kee Beef Noodles',
      restaurantImage: _image('photo-1569718212165-3a8278d5f624'),
      cuisine: 'Chinese',
      visitDate: DateTime(2026, 7, 24),
      postId: 'post-2',
    ),
  ],
  locations: _locations,
  reviewCount: 2,
  totalLikes: 140,
  achievements: const [
    JourneyAchievement(
      name: 'First Bite',
      description: 'Visit your first restaurant',
      category: 'visits',
      requirement: 1,
      points: 10,
      iconName: 'utensils',
    ),
    JourneyAchievement(
      name: 'Food Trail',
      description: 'Visit 5 different restaurants',
      category: 'visits',
      requirement: 5,
      points: 30,
      iconName: 'mapPin',
    ),
    JourneyAchievement(
      name: 'Makan Champion',
      description: 'Visit 20 restaurants',
      category: 'visits',
      requirement: 20,
      points: 100,
      iconName: 'trophy',
    ),
    JourneyAchievement(
      name: 'Review Rookie',
      description: 'Write your first review',
      category: 'reviews',
      requirement: 1,
      points: 10,
      iconName: 'penLine',
    ),
    JourneyAchievement(
      name: 'Review Regular',
      description: 'Write 10 reviews',
      category: 'reviews',
      requirement: 10,
      points: 50,
      iconName: 'star',
    ),
    JourneyAchievement(
      name: 'Cuisine Explorer',
      description: 'Try 3 different cuisines',
      category: 'cuisines',
      requirement: 3,
      points: 30,
      iconName: 'compass',
    ),
    JourneyAchievement(
      name: 'Cuisine Master',
      description: 'Try 7 different cuisines',
      category: 'cuisines',
      requirement: 7,
      points: 70,
      iconName: 'utensilsCrossed',
    ),
    JourneyAchievement(
      name: 'Community Voice',
      description: 'Get 50 total likes on your posts',
      category: 'social',
      requirement: 50,
      points: 50,
      iconName: 'heart',
    ),
    JourneyAchievement(
      name: 'Trendsetter',
      description: 'Get 100 total likes on your posts',
      category: 'social',
      requirement: 100,
      points: 100,
      iconName: 'flame',
    ),
    JourneyAchievement(
      name: 'Daily Makan',
      description: 'Log in on 7 different days',
      category: 'milestone',
      requirement: 7,
      points: 40,
      iconName: 'calendarCheck',
    ),
  ],
  scoreHistory: [
    JourneyScoreActivity(
      description: 'Posted review for Nasi Lemak Wanjo',
      points: 10,
      date: DateTime(2026, 7, 27),
      isReview: true,
    ),
    JourneyScoreActivity(
      description: 'Visited Nasi Lemak Wanjo',
      points: 5,
      date: DateTime(2026, 7, 26),
      isReview: false,
    ),
    JourneyScoreActivity(
      description: 'Visited Soong Kee Beef Noodles',
      points: 5,
      date: DateTime(2026, 7, 24),
      isReview: false,
    ),
  ],
);
