import 'dart:math';
import '../data/restaurant_repository.dart';
import '../../../shared/models/restaurant_model.dart';

class RecommendationService {
  final RestaurantRepository _repository;

  RecommendationService(this._repository);

  Future<List<RestaurantModel>> getPersonalizedRecommendations({
    required double latitude,
    required double longitude,
    required String budget,
    required String mealTime,
    List<String>? favoriteCategories,
  }) async {
    final allRestaurants = await _repository.searchRestaurants(priceRange: budget);
    
    // Scoring Algorithm
    final scoredRestaurants = allRestaurants.map((restaurant) {
      double score = 0;

      // 1. Distance Score (Closer is better)
      final distance = _calculateDistance(latitude, longitude, restaurant.latitude, restaurant.longitude);
      score += max(0, 50 - (distance / 1000)); // Max 50 points if within 50km

      // 2. Rating & Popularity Score
      score += restaurant.rating * 5; // Max 25 points
      score += min(25.0, restaurant.popularityScore / 10.0); // Max 25 points

      // 3. Meal Time Bonus
      if (_isMealTimeMatch(restaurant, mealTime)) {
        score += 20;
      }

      // 4. Hidden Gem Bonus
      if (restaurant.isHiddenGem) {
        score += 15;
      }

      return _ScoredRestaurant(restaurant, score);
    }).toList();

    scoredRestaurants.sort((a, b) => b.score.compareTo(a.score));

    return scoredRestaurants.take(10).map((s) => s.restaurant).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Distance in meters
  }

  bool _isMealTimeMatch(RestaurantModel restaurant, String mealTime) {
    if (mealTime == 'Breakfast' && restaurant.name.contains('Nasi Lemak')) return true;
    if (mealTime == 'Lunch' && restaurant.name.contains('Mee')) return true;
    if (mealTime == 'Dinner' && restaurant.name.contains('Cafe')) return true;
    return false;
  }
}

class _ScoredRestaurant {
  final RestaurantModel restaurant;
  final double score;

  _ScoredRestaurant(this.restaurant, this.score);
}
