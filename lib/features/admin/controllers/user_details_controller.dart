import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum UserDetailsStatus { loading, content, notFound, error }

enum UserAccountField { username, email, phone, communityScore }

class UserSaveResult {
  const UserSaveResult({this.error, this.invalidFields = const {}});

  final String? error;
  final Set<UserAccountField> invalidFields;
}

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

  /// Saves the editable fields and identifies fields that need correction.
  Future<UserSaveResult> save({
    required String rawUsername,
    required String rawEmail,
    required String rawPhone,
    required AdminUserRole role,
    required String rawCommunityScore,
  }) async {
    final username = rawUsername.trim();
    final email = rawEmail.trim();
    final phone = rawPhone.trim();
    final invalidFields = invalidFieldsFor(
      username: username,
      email: email,
      phone: phone,
      communityScore: rawCommunityScore,
    );
    if (invalidFields.isNotEmpty) {
      return UserSaveResult(
        error: 'Please enter valid information in the required fields.',
        invalidFields: invalidFields,
      );
    }
    final user = state.user;
    if (user == null) {
      return const UserSaveResult(
        error: 'Unable to update the user account. Please try again.',
      );
    }
    final communityScore = int.tryParse(rawCommunityScore.trim()) ?? 0;
    try {
      final duplicates = await Future.wait([
        _repository.usernameExists(username, user.id),
        _repository.emailExists(email, user.id),
        _repository.phoneExists(phone, user.id),
      ]);
      final duplicateFields = <UserAccountField>{
        if (duplicates[0]) UserAccountField.username,
        if (duplicates[1]) UserAccountField.email,
        if (duplicates[2]) UserAccountField.phone,
      };
      if (duplicateFields.isNotEmpty) {
        return UserSaveResult(
          error: 'The name,email address or phone number is already in use.',
          invalidFields: duplicateFields,
        );
      }
    } on Object {
      return const UserSaveResult(
        error: 'Unable to update the user account. Please try again.',
      );
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
      if (updated == null) {
        throw StateError('User update affected no rows.');
      }
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
      return const UserSaveResult();
    } on Object catch (error) {
      final duplicate = _isDuplicateError(error);
      state = state.copyWith(
        isSaving: false,
        errorMessage: duplicate
            ? 'The name,email address or phone number is already in use.'
            : 'Unable to update the user account. Please try again.',
      );
      return UserSaveResult(
        error: state.errorMessage,
        invalidFields: duplicate
            ? const {
                UserAccountField.username,
                UserAccountField.email,
                UserAccountField.phone,
              }
            : const {},
      );
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
      if (updated == null) {
        throw StateError('Account status update affected no rows.');
      }
      state = state.copyWith(user: updated);
      return null;
    } on Object {
      return newStatus == AdminAccountStatus.active
          ? 'Unable to activate the user account. Please try again.'
          : 'Unable to deactivate the user account. Please try again.';
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

  static bool _isDuplicateError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('23505') || message.contains('duplicate key');
  }

  static Set<UserAccountField> invalidFieldsFor({
    required String username,
    required String email,
    required String phone,
    required String communityScore,
  }) {
    final invalidFields = <UserAccountField>{};
    if (username.trim().isEmpty || !_namePattern.hasMatch(username.trim())) {
      invalidFields.add(UserAccountField.username);
    }
    if (email.trim().isEmpty || !_emailPattern.hasMatch(email.trim())) {
      invalidFields.add(UserAccountField.email);
    }
    if (phone.trim().isEmpty || !_phonePattern.hasMatch(phone.trim())) {
      invalidFields.add(UserAccountField.phone);
    }
    if (communityScore.trim().isNotEmpty) {
      final score = int.tryParse(communityScore.trim());
      if (score == null || score < 0) {
        invalidFields.add(UserAccountField.communityScore);
      }
    }
    return invalidFields;
  }
}
