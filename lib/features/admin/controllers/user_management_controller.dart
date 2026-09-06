import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

const _pageSize = 5;

enum UserManagementStatus { loading, content, loadingMore, empty, error }

class UserManagementState {
  const UserManagementState({
    required this.status,
    this.users = const [],
    this.searchQuery = '',
    this.statusFilter = UserStatusFilter.all,
    this.roleFilter = UserRoleFilter.all,
    this.hasMore = false,
    this.hasAppliedCriteria = false,
    this.pageError,
  });

  const UserManagementState.loading()
    : this(status: UserManagementStatus.loading);

  final UserManagementStatus status;
  final List<AdminUser> users;
  final String searchQuery;
  final UserStatusFilter statusFilter;
  final UserRoleFilter roleFilter;
  final bool hasMore;
  /// Distinguishes an empty database from an empty search/filter result.
  final bool hasAppliedCriteria;
  final String? pageError;

  UserManagementState copyWith({
    UserManagementStatus? status,
    List<AdminUser>? users,
    String? searchQuery,
    UserStatusFilter? statusFilter,
    UserRoleFilter? roleFilter,
    bool? hasMore,
    bool? hasAppliedCriteria,
    String? pageError,
  }) {
    return UserManagementState(
      status: status ?? this.status,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      roleFilter: roleFilter ?? this.roleFilter,
      hasMore: hasMore ?? this.hasMore,
      hasAppliedCriteria: hasAppliedCriteria ?? this.hasAppliedCriteria,
      pageError: pageError,
    );
  }
}

final userManagementControllerProvider =
    StateNotifierProvider.autoDispose<
      UserManagementController,
      UserManagementState
    >((ref) {
      final controller = UserManagementController(
        ref.watch(adminRepositoryProvider),
      );
      controller.loadFirstPage();
      return controller;
    });

class UserManagementController extends StateNotifier<UserManagementState> {
  UserManagementController(this._repository)
    : super(const UserManagementState.loading());

  final AdminRepository _repository;
  bool _isLoading = false;

  /// Monotonic request id. Any fetch that completes after a newer fetch has
  /// started is stale and must be ignored so fast search/filter changes are
  /// never overwritten by an older response.
  int _requestId = 0;

  Future<void> loadFirstPage() async {
    final requestId = ++_requestId;
    state = state.copyWith(
      status: UserManagementStatus.loading,
      users: const [],
      hasMore: false,
    );
    await _fetchPage(0, requestId);
  }

  Future<void> loadMore() async {
    if (_isLoading || !state.hasMore) return;
    state = state.copyWith(status: UserManagementStatus.loadingMore);
    await _fetchPage(state.users.length, _requestId);
  }

  void updateSearch(String value) {
    state = state.copyWith(
      searchQuery: value,
      hasAppliedCriteria:
          value.trim().isNotEmpty ||
          state.statusFilter != UserStatusFilter.all ||
          state.roleFilter != UserRoleFilter.all,
    );
    loadFirstPage();
  }

  void selectStatusFilter(UserStatusFilter filter) {
    state = state.copyWith(
      statusFilter: filter,
      hasAppliedCriteria:
          filter != UserStatusFilter.all ||
          state.roleFilter != UserRoleFilter.all ||
          state.searchQuery.trim().isNotEmpty,
    );
    loadFirstPage();
  }

  void selectRoleFilter(UserRoleFilter filter) {
    state = state.copyWith(
      roleFilter: filter,
      hasAppliedCriteria:
          filter != UserRoleFilter.all ||
          state.statusFilter != UserStatusFilter.all ||
          state.searchQuery.trim().isNotEmpty,
    );
    loadFirstPage();
  }

  Future<void> _fetchPage(int offset, int requestId) async {
    _isLoading = true;
    try {
      final page = await _repository.loadUsersPage(
        statusFilter: state.statusFilter,
        roleFilter: state.roleFilter,
        search: state.searchQuery,
        limit: _pageSize,
        offset: offset,
      );

      if (requestId != _requestId) return;
      final merged = offset == 0 ? page.items : [...state.users, ...page.items];
      state = state.copyWith(
        status: merged.isEmpty
            ? UserManagementStatus.empty
            : UserManagementStatus.content,
        users: List.unmodifiable(merged),
        hasMore: page.hasMore,
      );
    } on Object {
      if (requestId != _requestId) return;
      if (offset == 0) {
        state = state.copyWith(
          status: UserManagementStatus.error,
          pageError: 'Unable to retrieve user accounts. Please try again.',
        );
      } else {
        state = state.copyWith(
          status: UserManagementStatus.content,
          pageError: 'Unable to retrieve user accounts. Please try again.',
        );
      }
    } finally {
      if (requestId == _requestId) _isLoading = false;
    }
  }
}
