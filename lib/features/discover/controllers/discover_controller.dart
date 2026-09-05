import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/core/config/supabase_config.dart';
import '../models/discover_repository.dart';
import '../models/discover_restaurant.dart';
import '../models/fixture_discover_repository.dart';
import '../models/supabase_discover_repository.dart';
import 'discover_state.dart';

final savedRestaurantIdsProvider = StateProvider<Set<String>>((ref) {
  return const {};
});

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const FixtureDiscoverRepository();
  }
  try {
    return SupabaseDiscoverRepository(Supabase.instance.client);
  } on StateError {
    // Keeps previews and tests usable when main() has not initialized Supabase.
    return const FixtureDiscoverRepository();
  }
});

final discoverControllerProvider = StateNotifierProvider.autoDispose
    .family<DiscoverController, DiscoverState, DiscoverArguments>((ref, args) {
      final controller = DiscoverController(
        ref.watch(discoverRepositoryProvider),
        args,
        ref.read(savedRestaurantIdsProvider),
        (ids) => ref.read(savedRestaurantIdsProvider.notifier).state = ids,
      );
      controller.load();
      return controller;
    });

class DiscoverController extends StateNotifier<DiscoverState> {
  DiscoverController(
    this._repository,
    DiscoverArguments arguments,
    Set<String> initialBookmarks,
    this._onBookmarksChanged,
  ) : super(
        DiscoverState.loading(
          arguments,
        ).copyWith(bookmarkedIds: Set.unmodifiable(initialBookmarks)),
      );

  final DiscoverRepository _repository;
  final void Function(Set<String>) _onBookmarksChanged;
  List<DiscoverRestaurant> _allRestaurants = const [];

  DiscoverState get currentState => state;

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

  void toggleArea(String area) {
    state = state.copyWith(
      selectedAreas: _toggle(state.selectedAreas, area),
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
      selectedAreas: const {},
    );
    _applyFilters();
  }

  void toggleBookmark(String id) {
    final bookmarks = Set<String>.of(state.bookmarkedIds);
    if (!bookmarks.add(id)) {
      bookmarks.remove(id);
    }
    state = state.copyWith(bookmarkedIds: Set.unmodifiable(bookmarks));
    _onBookmarksChanged(Set.unmodifiable(bookmarks));
  }

  void selectRestaurant(String id) {
    state = state.copyWith(selectedRestaurantId: id);
  }

  void clearSelection() {
    state = state.copyWith(selectedRestaurantId: null);
  }

  void _applyFilters() {
    var restaurants = _allRestaurants.where(_matchesQuery).toList();
    restaurants = restaurants.where(_matchesSelections).toList();
    _sort(restaurants);
    final visibleIds = restaurants.map((r) => r.id).toSet();
    final selectedId = state.selectedRestaurantId;
    final preservedSelection =
        selectedId != null && visibleIds.contains(selectedId)
            ? selectedId
            : null;
    state = state.copyWith(
      status: restaurants.isEmpty
          ? DiscoverStatus.empty
          : DiscoverStatus.content,
      restaurants: List.unmodifiable(restaurants),
      selectedRestaurantId: preservedSelection,
    );
  }

  bool _matchesQuery(DiscoverRestaurant restaurant) {
    final query = state.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return restaurant.name.toLowerCase().contains(query) ||
        restaurant.cuisine.toLowerCase().contains(query) ||
        restaurant.categories.any((c) => c.toLowerCase().contains(query)) ||
        (restaurant.city?.toLowerCase().contains(query) ?? false) ||
        restaurant.description.toLowerCase().contains(query) ||
        restaurant.address.toLowerCase().contains(query);
  }

  bool _matchesSelections(DiscoverRestaurant restaurant) {
    if (state.selectedCuisines.isNotEmpty) {
      final matchesAnyCuisine = state.selectedCuisines.any(
        (selected) =>
            restaurant.cuisine.toLowerCase() == selected.toLowerCase() ||
            restaurant.categories.any(
              (cat) => cat.toLowerCase() == selected.toLowerCase(),
            ),
      );
      if (!matchesAnyCuisine) {
        return false;
      }
    }
    if (state.selectedBudgets.isNotEmpty &&
        !state.selectedBudgets.contains(restaurant.budget)) {
      return false;
    }
    if (state.selectedAreas.isNotEmpty) {
      final matchesAnyArea = state.selectedAreas.any((area) {
        final lowerArea = area.toLowerCase();
        final city = restaurant.city?.toLowerCase() ?? '';
        final address = restaurant.address.toLowerCase();
        return city.contains(lowerArea) || address.contains(lowerArea);
      });
      if (!matchesAnyArea) {
        return false;
      }
    }
    for (final filter in state.selectedFilters) {
      final matches = switch (filter) {
        'Saved' => state.bookmarkedIds.contains(restaurant.id),
        'Budget' => restaurant.budget == 'Low',
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
      case 'Newest Listings' || 'Newest':
        restaurants.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Name' || 'Name (A-Z)':
        restaurants.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'Popularity' || 'Recommendation Score':
      default:
        restaurants.sort((a, b) {
          final pop = b.popularityScore.compareTo(a.popularityScore);
          if (pop != 0) return pop;
          final rating = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (rating != 0) return rating;
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
