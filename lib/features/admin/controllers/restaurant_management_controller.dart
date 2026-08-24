import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum RestaurantManagementStatus { loading, content, empty, error }

class RestaurantManagementState {
  const RestaurantManagementState({
    required this.status,
    this.restaurants = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  const RestaurantManagementState.loading()
    : this(status: RestaurantManagementStatus.loading);

  final RestaurantManagementStatus status;
  final List<AdminRestaurant> restaurants;
  final String searchQuery;
  final String? errorMessage;

  RestaurantManagementState copyWith({
    RestaurantManagementStatus? status,
    List<AdminRestaurant>? restaurants,
    String? searchQuery,
    String? errorMessage,
  }) {
    return RestaurantManagementState(
      status: status ?? this.status,
      restaurants: restaurants ?? this.restaurants,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

final restaurantManagementControllerProvider =
    StateNotifierProvider.autoDispose<
      RestaurantManagementController,
      RestaurantManagementState
    >((ref) {
      final controller = RestaurantManagementController(
        ref.watch(adminRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class RestaurantManagementController
    extends StateNotifier<RestaurantManagementState> {
  RestaurantManagementController(this._repository)
    : super(const RestaurantManagementState.loading());

  final AdminRepository _repository;
  List<AdminRestaurant> _allRestaurants = const [];

  Future<void> load() async {
    state = const RestaurantManagementState.loading();
    try {
      _allRestaurants = await _repository.loadRestaurants();
      _applyFilter();
    } on Object {
      state = const RestaurantManagementState(
        status: RestaurantManagementStatus.error,
        errorMessage: 'We could not load restaurant records right now.',
      );
    }
  }

  void updateSearch(String value) {
    state = state.copyWith(searchQuery: value);
    _applyFilter();
  }

  void _applyFilter() {
    final query = state.searchQuery.trim().toLowerCase();
    final restaurants = _allRestaurants
        .where((restaurant) {
          return query.isEmpty ||
              restaurant.name.toLowerCase().contains(query) ||
              restaurant.categoriesDisplay.toLowerCase().contains(query) ||
              (restaurant.address ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
    state = state.copyWith(
      status: restaurants.isEmpty
          ? RestaurantManagementStatus.empty
          : RestaurantManagementStatus.content,
      restaurants: List.unmodifiable(restaurants),
    );
  }
}
