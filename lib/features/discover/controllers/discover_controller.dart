import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/core/config/supabase_config.dart';
import '../models/discover_repository.dart';
import '../models/discover_restaurant.dart';
import '../models/fixture_discover_repository.dart';
import '../models/supabase_discover_repository.dart';
import 'discover_state.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseDiscoverRepository(Supabase.instance.client);
  }
  return const FixtureDiscoverRepository();
});

final discoverControllerProvider = StateNotifierProvider.autoDispose
    .family<DiscoverController, DiscoverState, DiscoverArguments>((ref, args) {
      final controller = DiscoverController(
        ref.watch(discoverRepositoryProvider),
        args,
      );
      controller.load();
      return controller;
    });

class DiscoverController extends StateNotifier<DiscoverState> {
  DiscoverController(this._repository, DiscoverArguments arguments)
    : super(DiscoverState.loading(arguments));

  final DiscoverRepository _repository;
  List<DiscoverRestaurant> _allRestaurants = const [];

  Future<void> load() async {
    try {
      _allRestaurants = await _repository.loadRestaurants();
      _applyFilters();
    } on Object {
      state = state.copyWith(
        status: DiscoverStatus.error,
        errorMessage: 'We could not load restaurants right now.',
      );
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void toggleFilter(String filter) {
    state = state.copyWith(
      selectedFilters: _toggle(state.selectedFilters, filter),
    );
    _applyFilters();
  }

  void toggleCuisine(String cuisine) {
    state = state.copyWith(
      selectedCuisines: _toggle(state.selectedCuisines, cuisine),
    );
    _applyFilters();
  }

  void toggleBudget(String budget) {
    state = state.copyWith(
      selectedBudgets: _toggle(state.selectedBudgets, budget),
    );
    _applyFilters();
  }

  void selectSort(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
    _applyFilters();
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedFilters: const {},
      selectedCuisines: const {},
      selectedBudgets: const {},
    );
    _applyFilters();
  }

  void toggleBookmark(String id) {
    final bookmarks = Set<String>.of(state.bookmarkedIds);
    if (!bookmarks.add(id)) {
      bookmarks.remove(id);
    }
    state = state.copyWith(bookmarkedIds: Set.unmodifiable(bookmarks));
  }

  void _applyFilters() {
    var restaurants = _allRestaurants.where(_matchesQuery).toList();
    restaurants = restaurants.where(_matchesSelections).toList();
    _sort(restaurants);
    state = state.copyWith(
      status: restaurants.isEmpty
          ? DiscoverStatus.empty
          : DiscoverStatus.content,
      restaurants: List.unmodifiable(restaurants),
    );
  }

  bool _matchesQuery(DiscoverRestaurant restaurant) {
    final query = state.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return restaurant.name.toLowerCase().contains(query) ||
        restaurant.cuisine.toLowerCase().contains(query) ||
        restaurant.description.toLowerCase().contains(query) ||
        restaurant.address.toLowerCase().contains(query);
  }

  bool _matchesSelections(DiscoverRestaurant restaurant) {
    if (state.selectedCuisines.isNotEmpty &&
        !state.selectedCuisines.contains(restaurant.cuisine)) {
      return false;
    }
    if (state.selectedBudgets.isNotEmpty &&
        !state.selectedBudgets.contains(restaurant.budget)) {
      return false;
    }
    for (final filter in state.selectedFilters) {
      final matches = switch (filter) {
        'Hidden Gems' => restaurant.isHiddenGem,
        // Opening status cannot be derived reliably from free-form operating
        // hours, so only honour it when a source supplied the label.
        'Open Now' => restaurant.labels.contains('Open Now'),
        'Budget' => restaurant.budget == 'Low',
        'Mamak' => restaurant.cuisine == 'Mamak',
        'Street Food' => restaurant.cuisine == 'Street Food',
        'Desserts' => restaurant.cuisine == 'Desserts',
        _ => true,
      };
      if (!matches) {
        return false;
      }
    }
    return true;
  }

  void _sort(List<DiscoverRestaurant> restaurants) {
    final effectiveSort = state.selectedFilters.contains('Near Me')
        ? 'Distance'
        : state.sortBy;
    switch (effectiveSort) {
      case 'Distance':
        restaurants.sort(
          (a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999),
        );
      case 'Newest Listings':
        restaurants.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        restaurants.sort((a, b) {
          final ratingOrder = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (ratingOrder != 0) {
            return ratingOrder;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  Set<String> _toggle(Set<String> values, String value) {
    final result = Set<String>.of(values);
    if (!result.add(value)) {
      result.remove(value);
    }
    return Set.unmodifiable(result);
  }
}
