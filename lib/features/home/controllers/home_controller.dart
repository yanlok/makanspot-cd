import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant_repository.dart';
import '../models/recommendation_service.dart';
import '../../../shared/models/restaurant_model.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((Ref ref) {
  return RestaurantRepository(Supabase.instance.client);
});

final recommendationServiceProvider = Provider<RecommendationService>((Ref ref) {
  return RecommendationService(ref.watch(restaurantRepositoryProvider));
});

final trendingRestaurantsProvider = FutureProvider<List<RestaurantModel>>((Ref ref) async {
  return ref.watch(restaurantRepositoryProvider).getTrendingRestaurants();
});

final hiddenGemsProvider = FutureProvider<List<RestaurantModel>>((Ref ref) async {
  return ref.watch(restaurantRepositoryProvider).getHiddenGems();
});
