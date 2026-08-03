import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture_profile_repository.dart';
import '../models/profile_models.dart';
import '../models/profile_repository.dart';

enum ProfileStatus { loading, content, saving, saved, error }

class ProfileState {
  const ProfileState({required this.status, this.data, this.errorMessage});

  const ProfileState.loading() : this(status: ProfileStatus.loading);

  final ProfileStatus status;
  final ProfileData? data;
  final String? errorMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileData? data,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
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

  Future<void> load() async {
    state = const ProfileState.loading();
    try {
      state = ProfileState(
        status: ProfileStatus.content,
        data: await _repository.loadProfile(),
      );
    } on Object {
      state = const ProfileState(
        status: ProfileStatus.error,
        errorMessage: 'We could not load your profile right now.',
      );
    }
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
