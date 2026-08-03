import 'home_feed.dart';
import 'home_repository.dart';
import 'restaurant_summary.dart';

class FixtureHomeRepository implements HomeRepository {
  const FixtureHomeRepository();

  @override
  Future<HomeFeed> loadHome() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // The prototype requests Restaurant.list('-created_date', 50) before it
    // derives each Home section.
    final restaurants = _restaurants.reversed.toList();
    final recommended = List<RestaurantSummary>.of(restaurants)
      ..sort((first, second) {
        return (second.rating ?? 0).compareTo(first.rating ?? 0);
      });
    final hiddenGems = restaurants.where((item) => item.isHiddenGem).toList();
    final nearby = List<RestaurantSummary>.of(restaurants)
      ..sort((first, second) {
        return (first.distanceKm ?? 999).compareTo(second.distanceKm ?? 999);
      });

    return HomeFeed(
      firstName: 'Yih',
      location: 'Kuala Lumpur',
      profileAsset: 'assets/images/default_icon.jpg',
      recommended: List.unmodifiable(recommended),
      hiddenGems: List.unmodifiable(hiddenGems),
      nearby: List.unmodifiable(nearby),
      newest: List.unmodifiable(restaurants),
    );
  }
}

const _restaurants = <RestaurantSummary>[
  RestaurantSummary(
    id: 'rest-1',
    name: 'Nasi Lemak Wanjo',
    cuisine: 'Malaysian',
    rating: 4.7,
    distanceKm: 1.2,
    budget: 'Low',
    isHiddenGem: false,
    labels: ['Open Now', 'Popular'],
    imageUrl:
        'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?'
        'w=900&auto=format&fit=crop',
  ),
  RestaurantSummary(
    id: 'rest-2',
    name: 'Soong Kee Beef Noodles',
    cuisine: 'Chinese',
    rating: 4.5,
    distanceKm: 2.4,
    budget: 'Medium',
    isHiddenGem: true,
    labels: ['Open Now'],
    imageUrl:
        'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?'
        'w=900&auto=format&fit=crop',
  ),
  RestaurantSummary(
    id: 'rest-3',
    name: 'Restoran Rebung',
    cuisine: 'Malay',
    rating: 4.6,
    distanceKm: 3.1,
    budget: 'Medium',
    isHiddenGem: false,
    labels: ['Open Now', 'Halal'],
    imageUrl:
        'https://images.unsplash.com/photo-1547592180-85f173990554?'
        'w=900&auto=format&fit=crop',
  ),
  RestaurantSummary(
    id: 'rest-4',
    name: 'Brickfields Pisang Goreng',
    cuisine: 'Street Food',
    rating: 4.4,
    distanceKm: 4,
    budget: 'Low',
    isHiddenGem: true,
    labels: ['Open Now'],
    imageUrl:
        'https://images.unsplash.com/photo-1601050690597-df0568f70950?'
        'w=900&auto=format&fit=crop',
  ),
  RestaurantSummary(
    id: 'rest-5',
    name: 'Murni Discovery',
    cuisine: 'Mamak',
    rating: 4.3,
    distanceKm: 5.8,
    budget: 'Low',
    isHiddenGem: false,
    labels: ['Open Now', 'Late Night'],
    imageUrl:
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?'
        'w=900&auto=format&fit=crop',
  ),
  RestaurantSummary(
    id: 'rest-6',
    name: 'Inside Scoop',
    cuisine: 'Desserts',
    rating: 4.6,
    distanceKm: 6.2,
    budget: 'Medium',
    isHiddenGem: false,
    labels: ['Open Now'],
    imageUrl:
        'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?'
        'w=900&auto=format&fit=crop',
  ),
];
