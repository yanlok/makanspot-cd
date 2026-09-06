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
        ref,
        ref.watch(discoverRepositoryProvider),
        id,
      );
      controller.load();
      return controller;
    });

class RestaurantDetailsController
    extends StateNotifier<RestaurantDetailsState> {
  RestaurantDetailsController(this._ref, this._repository, this.restaurantId)
    : super(const RestaurantDetailsState.loading());

  final Ref _ref;
  final DiscoverRepository _repository;
  final String restaurantId;

  Future<void> load() async {
    if (!mounted) return;
    state = const RestaurantDetailsState.loading();
    try {
      final data = await _repository.loadRestaurant(restaurantId);
      if (!mounted) return;
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
      if (!mounted) return;
      state = const RestaurantDetailsState(
        status: RestaurantDetailsStatus.error,
        reviews: [],
        errorMessage: 'We could not load this restaurant right now.',
      );
    }
  }

  /// Saves or unsaves the current restaurant, keeping the shared
  /// [savedRestaurantIdsProvider] in sync.
  Future<void> toggleSaved() async {
    if (!mounted) return;
    await toggleRestaurantBookmark(_ref, restaurantId);
  }

  Future<void> toggleReviewLike(String reviewId) async {
    if (!mounted) return;
    try {
      final updated = await _repository.toggleReviewLike(reviewId);
      if (!mounted || updated == null) return;
      final reviews = state.reviews
          .map((review) => review.id == reviewId ? updated : review)
          .toList();
      state = state.copyWith(reviews: List.unmodifiable(reviews));
    } on Object {
      // Leave the current state unchanged; the like could not be persisted.
    }
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
