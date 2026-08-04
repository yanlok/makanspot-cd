import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum UserManagementStatus { loading, content, empty, error }

enum UserStatusFilter { all, active, deactivated }

class UserManagementState {
  const UserManagementState({
    required this.status,
    this.users = const [],
    this.searchQuery = '',
    this.statusFilter = UserStatusFilter.all,
    this.errorMessage,
  });

  const UserManagementState.loading()
    : this(status: UserManagementStatus.loading);

  final UserManagementStatus status;
  final List<AdminUser> users;
  final String searchQuery;
  final UserStatusFilter statusFilter;
  final String? errorMessage;

  UserManagementState copyWith({
    UserManagementStatus? status,
    List<AdminUser>? users,
    String? searchQuery,
    UserStatusFilter? statusFilter,
    String? errorMessage,
  }) {
    return UserManagementState(
      status: status ?? this.status,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      errorMessage: errorMessage,
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
      controller.load();
      return controller;
    });

class UserManagementController extends StateNotifier<UserManagementState> {
  UserManagementController(this._repository)
    : super(const UserManagementState.loading());

  final AdminRepository _repository;
  List<AdminUser> _allUsers = const [];

  Future<void> load() async {
    state = const UserManagementState.loading();
    try {
      _allUsers = await _repository.loadUsers();
      _applyFilters();
    } on Object {
      state = const UserManagementState(
        status: UserManagementStatus.error,
        errorMessage: 'We could not load user accounts right now.',
      );
    }
  }

  void updateSearch(String value) {
    state = state.copyWith(searchQuery: value);
    _applyFilters();
  }

  void selectStatusFilter(UserStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
    _applyFilters();
  }

  void _applyFilters() {
    final query = state.searchQuery.trim().toLowerCase();
    final users = _allUsers
        .where((user) {
          final matchesSearch =
              query.isEmpty ||
              user.username.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
          final matchesStatus =
              state.statusFilter == UserStatusFilter.all ||
              (state.statusFilter == UserStatusFilter.active &&
                  user.accountStatus == AdminAccountStatus.active) ||
              (state.statusFilter == UserStatusFilter.deactivated &&
                  user.accountStatus == AdminAccountStatus.deactivated);
          return matchesSearch && matchesStatus;
        })
        .toList(growable: false);
    state = state.copyWith(
      status: users.isEmpty
          ? UserManagementStatus.empty
          : UserManagementStatus.content,
      users: List.unmodifiable(users),
    );
  }
}
