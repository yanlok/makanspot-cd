import 'discover_restaurant.dart';

abstract interface class DiscoverRepository {
  Future<List<DiscoverRestaurant>> loadRestaurants();

  Future<RestaurantDetailsData?> loadRestaurant(String id);
}
