import 'discover_repository.dart';
import 'discover_restaurant.dart';

class FixtureDiscoverRepository implements DiscoverRepository {
  const FixtureDiscoverRepository();

  @override
  Future<List<DiscoverRestaurant>> loadRestaurants() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_restaurants);
  }

  @override
  Future<RestaurantDetailsData?> loadRestaurant(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final matches = _restaurants.where((item) => item.id == id);
    if (matches.isEmpty) {
      return null;
    }
    return RestaurantDetailsData(
      restaurant: matches.single,
      reviews: List.unmodifiable(_reviews[id] ?? const []),
    );
  }
}

final _restaurants = <DiscoverRestaurant>[
  DiscoverRestaurant(
    id: 'rest-1',
    name: 'Nasi Lemak Wanjo',
    cuisine: 'Malay',
    categories: const ['Malay', 'Street Food'],
    city: 'Kuala Lumpur',
    popularityScore: 95,
    budget: 'Low',
    isHiddenGem: false,
    labels: const ['Open Now', 'Popular'],
    imageUrl:
        'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?'
        'auto=format&fit=crop&w=900&q=80',
    rating: 4.7,
    distanceKm: 1.2,
    createdAt: DateTime.utc(2026, 7, 18, 9),
    address: '8, Jalan Raja Muda Musa, Kampung Baru, Kuala Lumpur',
    description:
        'A much-loved Kampung Baru stop for fragrant nasi lemak and ayam '
        'goreng berempah.',
    operatingHours: '7:00 AM – 12:00 AM',
    contact: '+60 3-2698 2233',
    latitude: 3.1617,
    longitude: 101.7048,
  ),
  DiscoverRestaurant(
    id: 'rest-2',
    name: 'Soong Kee Beef Noodles',
    cuisine: 'Chinese',
    categories: const ['Chinese', 'Street Food'],
    city: 'Kuala Lumpur',
    popularityScore: 88,
    budget: 'Medium',
    isHiddenGem: true,
    labels: const ['Open Now'],
    imageUrl:
        'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?'
        'auto=format&fit=crop&w=900&q=80',
    rating: 4.5,
    distanceKm: 2.4,
    createdAt: DateTime.utc(2026, 7, 20, 9),
    address: '86, Jalan Tun H S Lee, Kuala Lumpur',
    description:
        'Springy noodles, comforting beef broth and a classic KL coffee-shop '
        'atmosphere.',
    operatingHours: '7:30 AM – 4:00 PM',
    contact: '+60 3-2078 3536',
    latitude: 3.1459,
    longitude: 101.7003,
  ),
  DiscoverRestaurant(
    id: 'rest-3',
    name: 'Restoran Rebung',
    cuisine: 'Malay',
    categories: const ['Malay'],
    city: 'Kuala Lumpur',
    popularityScore: 78,
    budget: 'Medium',
    isHiddenGem: false,
    labels: const ['Open Now', 'Halal'],
    imageUrl:
        'https://images.unsplash.com/photo-1547592180-85f173990554?'
        'auto=format&fit=crop&w=900&q=80',
    rating: 4.6,
    distanceKm: 3.1,
    createdAt: DateTime.utc(2026, 7, 22, 9),
    address: '5-2, Jalan Jalal, Off Jalan Raja Abdullah, Kuala Lumpur',
    description:
        'Traditional Malay dishes served buffet-style in a warm, leafy '
        'setting.',
    operatingHours: '11:00 AM – 5:00 PM',
    contact: '+60 3-2602 3630',
    latitude: 3.1648,
    longitude: 101.7042,
  ),
  DiscoverRestaurant(
    id: 'rest-4',
    name: 'Brickfields Pisang Goreng',
    cuisine: 'Street Food',
    categories: const ['Street Food', 'Dessert & Bakery'],
    city: 'Kuala Lumpur',
    popularityScore: 82,
    budget: 'Low',
    isHiddenGem: true,
    labels: const ['Open Now'],
    imageUrl:
        'https://images.unsplash.com/photo-1601050690597-df0568f70950?'
        'auto=format&fit=crop&w=900&q=80',
    rating: 4.4,
    distanceKm: 4,
    createdAt: DateTime.utc(2026, 7, 23, 9),
    address: 'Jalan Tun Sambanthan, Brickfields, Kuala Lumpur',
    description:
        'Crisp, hot banana fritters that make an ideal afternoon snack.',
    operatingHours: '10:00 AM – 7:00 PM',
    latitude: 3.1307,
    longitude: 101.6869,
  ),
  DiscoverRestaurant(
    id: 'rest-5',
    name: 'Murni Discovery',
    cuisine: 'Mamak',
    categories: const ['Mamak', 'Street Food'],
    city: 'Petaling Jaya',
    popularityScore: 92,
    budget: 'Low',
    isHiddenGem: false,
    labels: const ['Open Now', 'Late Night'],
    imageUrl:
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?'
        'auto=format&fit=crop&w=900&q=80',
    rating: 4.3,
    distanceKm: 5.8,
    createdAt: DateTime.utc(2026, 7, 24, 9),
    address: '2, Jalan 21/19, Sea Park, Petaling Jaya',
    description:
        'Generous mamak favourites, toast and colourful drinks for supper.',
    operatingHours: '4:00 PM – 2:00 AM',
    contact: '+60 3-7877 7866',
    latitude: 3.105,
    longitude: 101.6385,
  ),
  DiscoverRestaurant(
    id: 'rest-6',
    name: 'Inside Scoop',
    cuisine: 'Dessert & Bakery',
    categories: const ['Dessert & Bakery', 'Cafe'],
    city: 'Bangsar',
    popularityScore: 90,
    budget: 'Medium',
    isHiddenGem: false,
    labels: const ['Open Now'],
    imageUrl:
        'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?'
        'auto=format&fit=crop&w=900&q=80',
    rating: 4.6,
    distanceKm: 6.2,
    createdAt: DateTime.utc(2026, 7, 25, 9),
    address: 'Jalan Telawi, Bangsar Baru, Kuala Lumpur',
    description:
        'Small-batch Malaysian ice cream in inventive rotating flavours.',
    operatingHours: '12:00 PM – 11:00 PM',
    latitude: 3.1291,
    longitude: 101.671,
  ),
];

const _reviews = <String, List<RestaurantReview>>{
  'rest-1': [
    RestaurantReview(
      id: 'post-1',
      username: 'Aisyah Rahman',
      profileTitle: 'Hidden Gem Hunter',
      reviewText:
          'The sambal has a lovely slow heat, the rice is fragrant with '
          'coconut, and the ayam goreng stays beautifully crunchy.',
      avatarUrl:
          'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?'
          'w=200&h=200&fit=crop',
      imageUrl:
          'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?'
          'auto=format&fit=crop&w=900&q=80',
      likes: 128,
      isLiked: false,
    ),
  ],
};
