import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture_profile_repository.dart';
import '../models/profile_models.dart';
import '../models/profile_repository.dart';

enum ProfileStatus { loading, content, saving, saved, error }

enum AccountListStatus { loading, content, empty, noResults, error }

class ProfileState {
  const ProfileState({
    required this.status,
    this.data,
    this.errorMessage,
    this.accountListStatus = AccountListStatus.loading,
    this.accountSummaries = const [],
    this.accountSearchQuery = '',
    this.roleFilter = AccountRoleFilter.all,
    this.statusFilter = AccountStatusFilter.all,
    this.accountErrorMessage,
  });

  const ProfileState.loading() : this(status: ProfileStatus.loading);

  final ProfileStatus status;
  final ProfileData? data;
  final String? errorMessage;
  final AccountListStatus accountListStatus;
  final List<DemoRegisteredAccount> accountSummaries;
  final String accountSearchQuery;
  final AccountRoleFilter roleFilter;
  final AccountStatusFilter statusFilter;
  final String? accountErrorMessage;

  bool get hasAccountFilters {
    return accountSearchQuery.trim().isNotEmpty ||
        roleFilter != AccountRoleFilter.all ||
        statusFilter != AccountStatusFilter.all;
  }

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileData? data,
    String? errorMessage,
    AccountListStatus? accountListStatus,
    List<DemoRegisteredAccount>? accountSummaries,
    String? accountSearchQuery,
    AccountRoleFilter? roleFilter,
    AccountStatusFilter? statusFilter,
    String? accountErrorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
      accountListStatus: accountListStatus ?? this.accountListStatus,
      accountSummaries: accountSummaries ?? this.accountSummaries,
      accountSearchQuery: accountSearchQuery ?? this.accountSearchQuery,
      roleFilter: roleFilter ?? this.roleFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      accountErrorMessage: accountErrorMessage ?? this.accountErrorMessage,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return FixtureProfileRepository();
});

final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, ProfileState>((ref) {
      final controller = ProfileController(
        ref.watch(profileRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository) : super(const ProfileState.loading());

  final ProfileRepository _repository;
  List<DemoRegisteredAccount> _allAccounts = const [];

  Future<void> load() async {
    state = const ProfileState.loading();
    try {
      final profileData = await _repository.loadProfile();
      state = ProfileState(
        status: ProfileStatus.content,
        data: profileData,
      );
      await reloadAccountSummaries();
    } on Object {
      state = const ProfileState(
        status: ProfileStatus.error,
        errorMessage: 'We could not load your profile right now.',
      );
    }
  }

  Future<void> reloadAccountSummaries() async {
    state = state.copyWith(accountListStatus: AccountListStatus.loading);
    try {
      _allAccounts = await _repository.loadDemoRegisteredAccounts();
      _applyAccountFilters();
    } on Object {
      state = state.copyWith(
        accountListStatus: AccountListStatus.error,
        accountErrorMessage: 'We could not retrieve account summaries.',
      );
    }
  }

  void updateAccountSearch(String value) {
    state = state.copyWith(accountSearchQuery: value);
    _applyAccountFilters();
  }

  void selectRoleFilter(AccountRoleFilter value) {
    state = state.copyWith(roleFilter: value);
    _applyAccountFilters();
  }

  void selectStatusFilter(AccountStatusFilter value) {
    state = state.copyWith(statusFilter: value);
    _applyAccountFilters();
  }

  void clearAccountFilters() {
    state = state.copyWith(
      accountSearchQuery: '',
      roleFilter: AccountRoleFilter.all,
      statusFilter: AccountStatusFilter.all,
    );
    _applyAccountFilters();
  }

  void _applyAccountFilters() {
    if (_allAccounts.isEmpty) {
      state = state.copyWith(
        accountListStatus: AccountListStatus.empty,
        accountSummaries: const [],
      );
      return;
    }

    final query = state.accountSearchQuery.trim().toLowerCase();
    final filtered = _allAccounts.where((account) {
      final matchesQuery =
          query.isEmpty ||
          account.name.toLowerCase().contains(query) ||
          account.email.toLowerCase().contains(query);
      final matchesRole =
          state.roleFilter == AccountRoleFilter.all ||
          account.role.toLowerCase() == state.roleFilter.name;
      final matchesStatus =
          state.statusFilter == AccountStatusFilter.all ||
          account.status.toLowerCase() == state.statusFilter.name;
      return matchesQuery && matchesRole && matchesStatus;
    }).toList(growable: false);

    state = state.copyWith(
      accountListStatus: filtered.isEmpty
          ? AccountListStatus.noResults
          : AccountListStatus.content,
      accountSummaries: List.unmodifiable(filtered),
    );
  }
}

final editProfileControllerProvider =
    StateNotifierProvider.autoDispose<EditProfileController, ProfileState>((
      ref,
    ) {
      final controller = EditProfileController(
        ref.watch(profileRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class EditProfileController extends StateNotifier<ProfileState> {
  EditProfileController(this._repository) : super(const ProfileState.loading());

  final ProfileRepository _repository;

  Future<void> load() async {
    try {
      state = ProfileState(
        status: ProfileStatus.content,
        data: await _repository.loadProfile(),
      );
    } on Object {
      state = const ProfileState(
        status: ProfileStatus.error,
        errorMessage: 'We could not open your profile right now.',
      );
    }
  }

  Future<String?> save({required String username, required String bio}) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty || state.data == null) {
      return 'Username required';
    }
    state = state.copyWith(status: ProfileStatus.saving);
    try {
      final profile = await _repository.saveProfile(
        username: trimmed,
        bio: bio.trim(),
        profileAsset: state.data!.profile.profileAsset,
      );
      state = ProfileState(
        status: ProfileStatus.saved,
        data: ProfileData(
          profile: profile,
          visits: state.data!.visits,
          reviews: state.data!.reviews,
          cuisines: state.data!.cuisines,
          earnedBadges: state.data!.earnedBadges,
        ),
      );
      return null;
    } on Object {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'We could not save your profile right now.',
      );
      return state.errorMessage;
    }
  }
}
