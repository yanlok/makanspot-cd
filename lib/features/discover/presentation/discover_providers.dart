import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../home/data/restaurant_repository.dart';
import '../../../shared/models/restaurant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final restaurantRepositoryProvider = Provider((Ref ref) {
  return RestaurantRepository(Supabase.instance.client);
});

final mapMarkersProvider = FutureProvider<Set<Marker>>((Ref ref) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  final restaurants = await repo.searchRestaurants();
  
  return restaurants.map((r) => Marker(
    markerId: MarkerId(r.id),
    position: LatLng(r.latitude, r.longitude),
    infoWindow: InfoWindow(
      title: r.name,
      snippet: '${r.rating} stars • ${r.priceRange}',
    ),
  )).toSet();
});

final discoverFilterProvider = StateProvider<String>((Ref ref) => 'All');

final filteredRestaurantsProvider = FutureProvider<List<RestaurantModel>>((Ref ref) async {
  final filter = ref.watch(discoverFilterProvider);
  final repo = ref.watch(restaurantRepositoryProvider);
  
  if (filter == 'Hidden Gems') {
    return await repo.getHiddenGems();
  } else if (filter == 'Trending') {
    return await repo.getTrendingRestaurants();
  }
  
  return await repo.searchRestaurants();
});
