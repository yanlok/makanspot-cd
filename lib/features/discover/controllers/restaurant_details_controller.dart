import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discover_repository.dart';
import 'discover_controller.dart';
import 'restaurant_details_state.dart';

final restaurantDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<RestaurantDetailsController, RestaurantDetailsState, String>((
      ref,
      id,
    ) {
      final controller = RestaurantDetailsController(
        ref.watch(discoverRepositoryProvider),
        id,
      );
      controller.load();
      return controller;
    });

class RestaurantDetailsController
    extends StateNotifier<RestaurantDetailsState> {
  RestaurantDetailsController(this._repository, this.restaurantId)
    : super(const RestaurantDetailsState.loading());

  final DiscoverRepository _repository;
  final String restaurantId;

  Future<void> load() async {
    state = const RestaurantDetailsState.loading();
    try {
      final data = await _repository.loadRestaurant(restaurantId);
      if (data == null) {
        state = const RestaurantDetailsState(
          status: RestaurantDetailsStatus.notFound,
          reviews: [],
        );
        return;
      }
      state = RestaurantDetailsState(
        status: RestaurantDetailsStatus.content,
        restaurant: data.restaurant,
        reviews: data.reviews,
      );
    } on Object {
      state = const RestaurantDetailsState(
        status: RestaurantDetailsStatus.error,
        reviews: [],
        errorMessage: 'We could not load this restaurant right now.',
      );
    }
  }

  void toggleReviewLike(String reviewId) {
    final reviews = state.reviews.map((review) {
      if (review.id != reviewId) {
        return review;
      }
      final isLiked = !review.isLiked;
      return review.copyWith(
        isLiked: isLiked,
        likes: isLiked ? review.likes + 1 : review.likes - 1,
      );
    }).toList();
    state = state.copyWith(reviews: List.unmodifiable(reviews));
  }

  Uri mapsDestination() {
    final restaurant = state.restaurant;
    if (restaurant?.latitude != null && restaurant?.longitude != null) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${restaurant!.latitude},${restaurant.longitude}',
      });
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${restaurant?.name ?? ''} ${restaurant?.address ?? ''}',
    });
  }
}
