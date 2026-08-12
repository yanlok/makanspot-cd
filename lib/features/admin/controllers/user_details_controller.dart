import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    required String rawEmail,
    required String rawPhone,
    required String profileTitle,
    required AdminUserRole role,
    required String rawCommunityScore,
  }) async {
    final username = rawUsername.trim();
    if (username.isEmpty) {
      return 'Username is required.';
    }
    final email = rawEmail.trim();
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    final phone = rawPhone.trim();
    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      return 'Enter a valid phone number.';
    }
    final user = state.user;
    if (user == null) {
      return null;
    }
    final communityScore = int.tryParse(rawCommunityScore.trim()) ?? 0;
    try {
      if (await _repository.emailExists(email, user.id)) {
        return 'This email is already in use.';
      }
      if (phone.isNotEmpty && await _repository.phoneExists(phone, user.id)) {
        return 'This phone number is already in use.';
      }
    } on Object {
      return 'Could not validate your changes right now.';
    }

    state = state.copyWith(isSaving: true);
    try {
      final updated = await _repository.updateUser(
        id: user.id,
        username: username,
        email: email,
        phone: phone,
        role: role,
        profileTitle: profileTitle.trim(),
        communityScore: communityScore,
      );
      await _recordAudit(
        action: 'update_user',
        target: updated,
        changes: {
          'username': {'from': user.username, 'to': username},
          'email': {'from': user.email, 'to': email},
          'phone': {'from': user.phone, 'to': phone},
          'role': {'from': user.role.value, 'to': role.value},
          'profile_title': {
            'from': user.profileTitle,
            'to': profileTitle.trim(),
          },
          'community_score': {
            'from': user.communityScore,
            'to': communityScore,
          },
        },
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
      await _recordAudit(
        action: 'toggle_account_status',
        target: updated,
        changes: {
          'is_active': {
            'from': user.accountStatus == AdminAccountStatus.active,
            'to': newStatus == AdminAccountStatus.active,
          },
        },
      );
      state = state.copyWith(user: updated);
      return null;
    } on Object {
      return 'Could not update status.';
    }
  }

  Future<void> _recordAudit({
    required String action,
    required AdminUser? target,
    required Map<String, Map<String, Object?>> changes,
  }) async {
    if (target == null) {
      return;
    }
    String adminId = _fallbackAdminId;
    String adminName = _fallbackAdminUsername;
    try {
      final session = Supabase.instance.client.auth.currentUser;
      adminId = session?.id ?? adminId;
      adminName = session?.email ?? adminName;
    } on Object {
      // Supabase is not initialized (tests or fixture mode); fall back to
      // the fixed administrator identity.
    }
    await _repository.logAdminAction(
      adminUserId: adminId,
      adminUsername: adminName,
      action: action,
      targetUserId: target.id,
      targetUsername: target.username,
      fieldChanges: changes,
    );
  }

  static const _fallbackAdminId = '00000000-0000-0000-0000-000000000000';
  static const _fallbackAdminUsername = 'admin@makanspot.my';
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phonePattern = RegExp(r'^\+?[0-9][0-9\s\-()]{6,}$');
}
