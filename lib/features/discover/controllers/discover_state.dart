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
    required this.sortBy,
    required this.restaurants,
    required this.bookmarkedIds,
    this.errorMessage,
  });

  factory DiscoverState.loading(DiscoverArguments arguments) {
    final filters = <String>{};
    if (arguments.filter.isNotEmpty) {
      filters.add(arguments.filter);
    }
    var sortBy = 'Popularity';
    switch (arguments.section) {
      case 'hidden_gems':
        filters.add('Hidden Gems');
      case 'nearby':
        sortBy = 'Distance';
      case 'newest':
        sortBy = 'Newest Listings';
      case 'recommended':
        sortBy = 'Recommendation Score';
    }
    return DiscoverState(
      status: DiscoverStatus.loading,
      searchQuery: arguments.query,
      selectedFilters: Set.unmodifiable(filters),
      selectedCuisines: const {},
      selectedBudgets: const {},
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
  final String sortBy;
  final List<DiscoverRestaurant> restaurants;
  final Set<String> bookmarkedIds;
  final String? errorMessage;

  int get activeFilterCount {
    return selectedFilters.length +
        selectedCuisines.length +
        selectedBudgets.length;
  }

  DiscoverState copyWith({
    DiscoverStatus? status,
    String? searchQuery,
    Set<String>? selectedFilters,
    Set<String>? selectedCuisines,
    Set<String>? selectedBudgets,
    String? sortBy,
    List<DiscoverRestaurant>? restaurants,
    Set<String>? bookmarkedIds,
    String? errorMessage,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedCuisines: selectedCuisines ?? this.selectedCuisines,
      selectedBudgets: selectedBudgets ?? this.selectedBudgets,
      sortBy: sortBy ?? this.sortBy,
      restaurants: restaurants ?? this.restaurants,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      errorMessage: errorMessage,
    );
  }
}
