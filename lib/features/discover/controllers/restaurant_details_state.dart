import 'package:flutter/foundation.dart';

import '../models/discover_restaurant.dart';

enum RestaurantDetailsStatus { loading, content, notFound, error }

@immutable
class RestaurantDetailsState {
  const RestaurantDetailsState({
    required this.status,
    required this.reviews,
    this.restaurant,
    this.errorMessage,
  });

  const RestaurantDetailsState.loading()
    : this(status: RestaurantDetailsStatus.loading, reviews: const []);

  final RestaurantDetailsStatus status;
  final DiscoverRestaurant? restaurant;
  final List<RestaurantReview> reviews;
  final String? errorMessage;

  RestaurantDetailsState copyWith({
    RestaurantDetailsStatus? status,
    DiscoverRestaurant? restaurant,
    List<RestaurantReview>? reviews,
    String? errorMessage,
  }) {
    return RestaurantDetailsState(
      status: status ?? this.status,
      restaurant: restaurant ?? this.restaurant,
      reviews: reviews ?? this.reviews,
      errorMessage: errorMessage,
    );
  }
}
