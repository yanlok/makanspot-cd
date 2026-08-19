import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum UserDetailsStatus { loading, content, notFound, error }

class UserDetailsState {
  const UserDetailsState({
    required this.status,
    this.user,
    this.accountId,
    this.isSaving = false,
    this.errorMessage,
  });

  const UserDetailsState.loading() : this(status: UserDetailsStatus.loading);

  final UserDetailsStatus status;
  final AdminUser? user;
  final String? accountId;
  final bool isSaving;
  final String? errorMessage;

  UserDetailsState copyWith({
    UserDetailsStatus? status,
    AdminUser? user,
    String? accountId,
    bool? isSaving,
    String? errorMessage,
  }) {
    return UserDetailsState(
      status: status ?? this.status,
      user: user ?? this.user,
      accountId: accountId ?? this.accountId,
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
  List<AdminUser> _allUsers = const [];

  Future<void> load() async {
    state = const UserDetailsState.loading();
    try {
      _allUsers = await _repository.loadUsers();
      final matches = _allUsers.where((user) => user.id == _userId);
      if (matches.isEmpty) {
        state = const UserDetailsState(status: UserDetailsStatus.notFound);
        return;
      }
      final user = matches.single;
      state = UserDetailsState(
        status: UserDetailsStatus.content,
        user: user,
        accountId: adminUserAccountId(user, _allUsers),
      );
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
    required AdminUserRole role,
    required String rawCommunityScore,
  }) async {
    final username = rawUsername.trim();
    final email = rawEmail.trim();
    final phone = rawPhone.trim();
    final missingFields = <String>[
      if (username.isEmpty) 'Name',
      if (email.isEmpty) 'Email',
      if (phone.isEmpty) 'Phone number',
    ];
    if (missingFields.length == 3) {
      return 'Name,Email,Phone number is required';
    }
    if (missingFields.length == 1) {
      return '${missingFields.single} is required';
    }
    if (missingFields.isNotEmpty) {
      return '${missingFields.join(' and ')} are required';
    }
    if (!_namePattern.hasMatch(username)) {
      return 'Name can contain letters and underscores only.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (!_phonePattern.hasMatch(phone)) {
      return 'Enter a valid phone number.';
    }
    final user = state.user;
    if (user == null) {
      return null;
    }
    final communityScore = int.tryParse(rawCommunityScore.trim()) ?? 0;
    try {
      final duplicates = await Future.wait([
        _repository.usernameExists(username, user.id),
        _repository.emailExists(email, user.id),
        _repository.phoneExists(phone, user.id),
      ]);
      final duplicateFields = <String>[
        if (duplicates[0]) 'Name',
        if (duplicates[1]) 'Email',
        if (duplicates[2]) 'Phone number',
      ];
      if (duplicateFields.length == 1) {
        return '${duplicateFields.single} is already in use.';
      }
      if (duplicateFields.isNotEmpty) {
        return '${duplicateFields.join(', ')} are already in use.';
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
        communityScore: communityScore,
      );
      await _recordAudit(
        action: 'update_user',
        target: updated,
        changes: {
          if (user.username != username)
            'username': {'from': user.username, 'to': username},
          if (user.email != email) 'email': {'from': user.email, 'to': email},
          if (user.phone != phone) 'phone': {'from': user.phone, 'to': phone},
          if (user.role != role)
            'role': {'from': user.role.value, 'to': role.value},
          if (user.communityScore != communityScore)
            'community_score': {
              'from': user.communityScore,
              'to': communityScore,
            },
        },
      );
      if (updated != null) {
        _allUsers = [
          for (final existing in _allUsers)
            if (existing.id == updated.id) updated else existing,
        ];
      }
      state = state.copyWith(
        isSaving: false,
        user: updated,
        accountId: updated == null
            ? null
            : adminUserAccountId(updated, _allUsers),
      );
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
  static final _namePattern = RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ_]+$');
  static final _emailPattern = RegExp(
    r'^[^@\s]+@gmail\.com$',
    caseSensitive: false,
  );
  static final _phonePattern = RegExp(r'^0\d{2}-\d{7}$');
}
