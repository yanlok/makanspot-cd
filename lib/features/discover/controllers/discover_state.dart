import 'package:flutter/foundation.dart';

import '../models/discover_restaurant.dart';

enum DiscoverStatus { loading, content, empty, error }

@immutable
class DiscoverArguments {
  const DiscoverArguments({
    this.query = '',
    this.filter = '',
    this.section = '',
  });

  final String query;
  final String filter;
  final String section;

  @override
  bool operator ==(Object other) {
    return other is DiscoverArguments &&
        other.query == query &&
        other.filter == filter &&
        other.section == section;
  }

  @override
  int get hashCode => Object.hash(query, filter, section);
}

@immutable
class DiscoverState {
  const DiscoverState({
    required this.status,
    required this.searchQuery,
    required this.selectedFilters,
    required this.selectedCuisines,
    required this.selectedBudgets,
    this.selectedAreas = const {},
    required this.sortBy,
    required this.restaurants,
    required this.bookmarkedIds,
    this.errorMessage,
    this.selectedRestaurantId,
  });

  factory DiscoverState.loading(DiscoverArguments arguments) {
    final filters = <String>{};
    final cuisines = <String>{};
    final budgets = <String>{};
    var sortBy = 'Popularity';

    if (arguments.filter.isNotEmpty) {
      final f = arguments.filter;
      if (f == 'Saved') {
        filters.add('Saved');
      } else if (f == 'Budget' || f == 'Low') {
        budgets.add('Low');
      } else if (f == 'Desserts' || f == 'Dessert & Bakery') {
        cuisines.add('Dessert & Bakery');
      } else if (f == 'Near Me') {
        sortBy = 'Distance';
      } else {
        cuisines.add(f);
      }
    }
    switch (arguments.section) {
      case 'nearby':
        sortBy = 'Distance';
      case 'newest':
        sortBy = 'Newest Listings';
      case 'recommended' || 'hidden_gems':
        sortBy = 'Popularity';
    }
    return DiscoverState(
      status: DiscoverStatus.loading,
      searchQuery: arguments.query,
      selectedFilters: Set.unmodifiable(filters),
      selectedCuisines: Set.unmodifiable(cuisines),
      selectedBudgets: Set.unmodifiable(budgets),
      selectedAreas: const {},
      sortBy: sortBy,
      restaurants: const [],
      bookmarkedIds: const {},
    );
  }

  final DiscoverStatus status;
  final String searchQuery;
  final Set<String> selectedFilters;
  final Set<String> selectedCuisines;
  final Set<String> selectedBudgets;
  final Set<String> selectedAreas;
  final String sortBy;
  final List<DiscoverRestaurant> restaurants;
  final Set<String> bookmarkedIds;
  final String? errorMessage;
  final String? selectedRestaurantId;

  int get activeFilterCount {
    return selectedFilters.length +
        selectedCuisines.length +
        selectedBudgets.length +
        selectedAreas.length;
  }

  DiscoverState copyWith({
    DiscoverStatus? status,
    String? searchQuery,
    Set<String>? selectedFilters,
    Set<String>? selectedCuisines,
    Set<String>? selectedBudgets,
    Set<String>? selectedAreas,
    String? sortBy,
    List<DiscoverRestaurant>? restaurants,
    Set<String>? bookmarkedIds,
    String? errorMessage,
    Object? selectedRestaurantId = _sentinel,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedCuisines: selectedCuisines ?? this.selectedCuisines,
      selectedBudgets: selectedBudgets ?? this.selectedBudgets,
      selectedAreas: selectedAreas ?? this.selectedAreas,
      sortBy: sortBy ?? this.sortBy,
      restaurants: restaurants ?? this.restaurants,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      errorMessage: errorMessage,
      selectedRestaurantId: identical(selectedRestaurantId, _sentinel)
          ? this.selectedRestaurantId
          : selectedRestaurantId as String?,
    );
  }

  static const Object _sentinel = Object();
}
