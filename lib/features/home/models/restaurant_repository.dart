import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/restaurant_model.dart';

class RestaurantRepository {
  final SupabaseClient _supabase;

  RestaurantRepository(this._supabase);

  Future<List<RestaurantModel>> getTrendingRestaurants() async {
    final data = await _supabase
        .from('restaurants')
        .select('*, restaurant_images(image_url)')
        .eq('is_trending', true)
        .eq('is_approved', true)
        .limit(10);

    return (data as List).map((json) {
      final imageUrls = (json['restaurant_images'] as List?)
          ?.map((img) => img['image_url'] as String)
          .toList();
      return RestaurantModel.fromJson({...json, 'imageUrls': imageUrls});
    }).toList();
  }

  Future<List<RestaurantModel>> getHiddenGems() async {
    final data = await _supabase
        .from('restaurants')
        .select('*, restaurant_images(image_url)')
        .eq('is_hidden_gem', true)
        .eq('is_approved', true)
        .limit(10);

    return (data as List).map((json) {
      final imageUrls = (json['restaurant_images'] as List?)
          ?.map((img) => img['image_url'] as String)
          .toList();
      return RestaurantModel.fromJson({...json, 'imageUrls': imageUrls});
    }).toList();
  }

  Future<List<RestaurantModel>> searchRestaurants({
    String? query,
    String? category,
    String? priceRange,
    double? maxDistance,
  }) async {
    // When filtering by category, inner-join the junction + categories tables so
    // only restaurants linked to that category name are returned.
    final selectColumns = category != null
        ? '*, restaurant_images(image_url), restaurant_categories!inner(categories!inner(name))'
        : '*, restaurant_images(image_url)';
    var builder = _supabase.from('restaurants').select(selectColumns);

    if (query != null) {
      builder = builder.ilike('name', '%$query%');
    }

    if (priceRange != null) {
      builder = builder.eq('price_range', priceRange);
    }

    if (category != null) {
      builder = builder.eq('restaurant_categories.categories.name', category);
    }

    final data = await builder.eq('is_approved', true);

    return (data as List).map((json) {
      final imageUrls = (json['restaurant_images'] as List?)
          ?.map((img) => img['image_url'] as String)
          .toList();
      return RestaurantModel.fromJson({...json, 'imageUrls': imageUrls});
    }).toList();
  }
}
