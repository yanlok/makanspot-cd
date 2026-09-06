import 'discover_restaurant.dart';

abstract interface class DiscoverRepository {
  Future<List<DiscoverRestaurant>> loadRestaurants();

  Future<RestaurantDetailsData?> loadRestaurant(String id);

  /// Toggles the signed-in user's like on a review (post) and returns the
  /// review with fresh like state.
  Future<RestaurantReview?> toggleReviewLike(String id);

  /// IDs of restaurants the signed-in user has bookmarked.
  Future<Set<String>> loadBookmarkedRestaurantIds();

  /// Persists (or removes) a restaurant bookmark for the signed-in user.
  Future<void> setRestaurantBookmark(String restaurantId, {required bool saved});
}
