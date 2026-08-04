import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum UserDetailsStatus { loading, content, notFound, error }

class UserDetailsState {
  const UserDetailsState({
    required this.status,
    this.user,
    this.isSaving = false,
    this.errorMessage,
  });

  const UserDetailsState.loading() : this(status: UserDetailsStatus.loading);

  final UserDetailsStatus status;
  final AdminUser? user;
  final bool isSaving;
  final String? errorMessage;

  UserDetailsState copyWith({
    UserDetailsStatus? status,
    AdminUser? user,
    bool? isSaving,
    String? errorMessage,
  }) {
    return UserDetailsState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

final userDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<UserDetailsController, UserDetailsState, String>((ref, id) {
      final controller = UserDetailsController(
        ref.watch(adminRepositoryProvider),
        id,
      );
      controller.load();
      return controller;
    });

class UserDetailsController extends StateNotifier<UserDetailsState> {
  UserDetailsController(this._repository, this._userId)
    : super(const UserDetailsState.loading());

  final AdminRepository _repository;
  final String _userId;

  Future<void> load() async {
    state = const UserDetailsState.loading();
    try {
      final user = await _repository.loadUser(_userId);
      if (user == null) {
        state = const UserDetailsState(status: UserDetailsStatus.notFound);
        return;
      }
      state = UserDetailsState(status: UserDetailsStatus.content, user: user);
    } on Object {
      state = const UserDetailsState(
        status: UserDetailsStatus.error,
        errorMessage: 'We could not load this user right now.',
      );
    }
  }

  /// Saves the editable fields and returns a user-facing failure message,
  /// or null when the save succeeded.
  Future<String?> save({
    required String rawUsername,
    required String profileTitle,
    required String rawCommunityScore,
  }) async {
    final username = rawUsername.trim();
    if (username.isEmpty) {
      return 'Username required';
    }
    final user = state.user;
    if (user == null) {
      return null;
    }
    state = state.copyWith(isSaving: true);
    try {
      final updated = await _repository.updateUser(
        id: user.id,
        username: username,
        profileTitle: profileTitle.trim(),
        communityScore: int.tryParse(rawCommunityScore.trim()) ?? 0,
      );
      state = state.copyWith(isSaving: false, user: updated);
      return null;
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save changes.',
      );
      return state.errorMessage;
    }
  }

  /// Toggles the account between active and deactivated.
  Future<String?> toggleAccountStatus() async {
    final user = state.user;
    if (user == null) {
      return null;
    }
    final newStatus = user.accountStatus == AdminAccountStatus.active
        ? AdminAccountStatus.deactivated
        : AdminAccountStatus.active;
    try {
      final updated = await _repository.setUserAccountStatus(
        user.id,
        newStatus,
      );
      state = state.copyWith(user: updated);
      return null;
    } on Object {
      return 'Could not update status.';
    }
  }
}
