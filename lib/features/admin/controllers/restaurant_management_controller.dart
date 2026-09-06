import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

const _pageSize = 10;

enum RestaurantManagementStatus { loading, content, loadingMore, empty, error }

class RestaurantManagementState {
  const RestaurantManagementState({
    required this.status,
    this.restaurants = const [],
    this.searchQuery = '',
    this.statusFilter = RestaurantStatusFilter.active,
    this.sort = RestaurantSort.nameAscending,
    this.hasMore = false,
    this.hasAppliedCriteria = false,
    this.pageError,
  });

  const RestaurantManagementState.loading()
    : this(status: RestaurantManagementStatus.loading);

  final RestaurantManagementStatus status;
  final List<AdminRestaurant> restaurants;
  final String searchQuery;
  final RestaurantStatusFilter statusFilter;
  final RestaurantSort sort;
  final bool hasMore;
  /// Distinguishes an empty database from an empty search/filter result.
  final bool hasAppliedCriteria;
  final String? pageError;

  RestaurantManagementState copyWith({
    RestaurantManagementStatus? status,
    List<AdminRestaurant>? restaurants,
    String? searchQuery,
    RestaurantStatusFilter? statusFilter,
    RestaurantSort? sort,
    bool? hasMore,
    bool? hasAppliedCriteria,
    String? pageError,
  }) {
    return RestaurantManagementState(
      status: status ?? this.status,
      restaurants: restaurants ?? this.restaurants,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      sort: sort ?? this.sort,
      hasMore: hasMore ?? this.hasMore,
      hasAppliedCriteria: hasAppliedCriteria ?? this.hasAppliedCriteria,
      pageError: pageError,
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
      controller.loadFirstPage();
      return controller;
    });

class RestaurantManagementController
    extends StateNotifier<RestaurantManagementState> {
  RestaurantManagementController(this._repository)
    : super(const RestaurantManagementState.loading());

  final AdminRepository _repository;
  bool _isLoading = false;

  /// Monotonic request id. Any fetch that completes after a newer fetch has
  /// started is stale and must be ignored so fast search/filter changes are
  /// never overwritten by an older response.
  int _requestId = 0;

  Future<void> loadFirstPage() async {
    final requestId = ++_requestId;
    // Do not leave stale results on screen if the replacement request fails;
    // the administrator should see the retrieval failure and its retry action.
    state = state.copyWith(
      status: RestaurantManagementStatus.loading,
      restaurants: const [],
      hasMore: false,
    );
    await _fetchPage(0, requestId);
  }

  Future<void> loadMore() async {
    if (_isLoading || !state.hasMore) return;
    state = state.copyWith(status: RestaurantManagementStatus.loadingMore);
    await _fetchPage(state.restaurants.length, _requestId);
  }

  void updateSearch(String value) {
    state = state.copyWith(
      searchQuery: value,
      hasAppliedCriteria:
          value.trim().isNotEmpty ||
          state.statusFilter != RestaurantStatusFilter.active,
    );
    loadFirstPage();
  }

  void selectStatusFilter(RestaurantStatusFilter filter) {
    state = state.copyWith(
      statusFilter: filter,
      hasAppliedCriteria:
          filter != RestaurantStatusFilter.active ||
          state.searchQuery.trim().isNotEmpty,
    );
    loadFirstPage();
  }

  void selectSort(RestaurantSort sort) {
    state = state.copyWith(sort: sort);
    loadFirstPage();
  }

  Future<void> _fetchPage(int offset, int requestId) async {
    _isLoading = true;
    try {
      final page = await _repository.loadRestaurants(
        statusFilter: state.statusFilter,
        sort: state.sort,
        search: state.searchQuery,
        limit: _pageSize,
        offset: offset,
      );

      if (requestId != _requestId) return;
      final merged = offset == 0
          ? page.items
          : [...state.restaurants, ...page.items];
      state = state.copyWith(
        status: merged.isEmpty
            ? RestaurantManagementStatus.empty
            : RestaurantManagementStatus.content,
        restaurants: List.unmodifiable(merged),
        hasMore: page.hasMore,
      );
    } on Object {
      if (requestId != _requestId) return;
      if (offset == 0) {
        state = state.copyWith(
          status: RestaurantManagementStatus.error,
          pageError: 'Unable to retrieve restaurant information. Please try again.',
        );
      } else {
        state = state.copyWith(
          status: RestaurantManagementStatus.content,
          pageError: 'Unable to retrieve restaurant information. Please try again.',
        );
      }
    } finally {
      if (requestId == _requestId) _isLoading = false;
    }
  }
}
