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
  JourneyLocation(
    id: 'rest-3',
    name: 'Village Park Nasi Lemak',
    cuisine: 'Malaysian',
    imageUrl: _image('photo-1512058564366-18510be2db19'),
    address: '5, Jalan SS 21/37, Damansara Utama, Petaling Jaya',
    latitude: 3.1362,
    longitude: 101.6226,
  ),
  JourneyLocation(
    id: 'rest-4',
    name: 'Brickfields Pisang Goreng',
    cuisine: 'Street Food',
    imageUrl: _image('photo-1525351484163-7529414344d8'),
    address: 'Jalan Thambipillay, Brickfields, Kuala Lumpur',
    latitude: 3.1328,
    longitude: 101.6874,
  ),
  JourneyLocation(
    id: 'rest-5',
    name: 'Restoran Kin Kin',
    cuisine: 'Chinese',
    imageUrl: _image('photo-1563245372-f21724e3856d'),
    address: '40, Jalan Dewan Sultan Sulaiman, Kampung Baru, Kuala Lumpur',
    latitude: 3.1611,
    longitude: 101.6978,
  ),
  // Intentionally missing coordinates to exercise the list fallback.
  JourneyLocation(
    id: 'rest-6',
    name: 'Burp & Giggles',
    cuisine: 'Western',
    imageUrl: _image('photo-1466978913421-dad2ebd01d17'),
    address: '93, Jalan Dhoby, Ipoh, Perak',
    latitude: 0,
    longitude: 0,
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
    JourneyVisit(
      id: 'visit-3',
      restaurantId: 'rest-3',
      restaurantName: 'Village Park Nasi Lemak',
      restaurantImage: _image('photo-1512058564366-18510be2db19'),
      cuisine: 'Malaysian',
      visitDate: DateTime(2026, 7, 20),
      postId: 'post-3',
    ),
    JourneyVisit(
      id: 'visit-4',
      restaurantId: 'rest-4',
      restaurantName: 'Brickfields Pisang Goreng',
      restaurantImage: _image('photo-1525351484163-7529414344d8'),
      cuisine: 'Street Food',
      visitDate: DateTime(2026, 7, 15),
      postId: 'post-4',
    ),
    JourneyVisit(
      id: 'visit-5',
      restaurantId: 'rest-5',
      restaurantName: 'Restoran Kin Kin',
      restaurantImage: _image('photo-1563245372-f21724e3856d'),
      cuisine: 'Chinese',
      visitDate: DateTime(2026, 7, 10),
      postId: 'post-5',
    ),
    JourneyVisit(
      id: 'visit-6',
      restaurantId: 'rest-6',
      restaurantName: 'Burp & Giggles',
      restaurantImage: _image('photo-1466978913421-dad2ebd01d17'),
      cuisine: 'Western',
      visitDate: DateTime(2026, 7, 5),
      postId: 'post-6',
    ),
  ],
  locations: _locations,
  reviewCount: 6,
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
