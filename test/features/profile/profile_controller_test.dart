import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:makanspot/features/profile/controllers/profile_controller.dart';
import 'package:makanspot/features/profile/models/profile_models.dart';
import 'package:makanspot/features/profile/models/profile_repository.dart';

void main() {
  group('ProfileController', () {
    test('loads the profile into content state', () async {
      final repository = FakeProfileRepository();
      final controller = ProfileController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, ProfileStatus.content);
      expect(controller.state.data?.profile.username, 'Yih Loong');
      expect(controller.state.data?.visits, 2);
    });

    test('maps a load failure to the error state', () async {
      final repository = FakeProfileRepository()
        ..loadError = StateError('boom');
      final controller = ProfileController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, ProfileStatus.error);
      expect(
        controller.state.errorMessage,
        contains('could not load your profile'),
      );
    });
  });

  group('EditProfileController.save', () {
    test('rejects an empty username', () async {
      final repository = FakeProfileRepository();
      final controller = EditProfileController(repository);
      await controller.load();
      addTearDown(controller.dispose);

      final error = await controller.save(username: '  ', bio: 'bio');

      expect(error, 'Username required');
      expect(controller.state.status, ProfileStatus.content);
    });

    test('persists edited username and bio', () async {
      final repository = FakeProfileRepository();
      final controller = EditProfileController(repository);
      await controller.load();
      addTearDown(controller.dispose);

      final error = await controller.save(
        username: 'Yih',
        bio: 'Updated bio',
        currentProfileAsset: defaultProfileAsset,
      );

      expect(error, isNull);
      expect(controller.state.status, ProfileStatus.saved);
      expect(repository.lastSavedUsername, 'Yih');
      expect(repository.lastSavedBio, 'Updated bio');
      expect(controller.state.data?.profile.username, 'Yih');
    });

    test('uploads a new photo before saving the profile', () async {
      final repository = FakeProfileRepository();
      final controller = EditProfileController(repository);
      await controller.load();
      addTearDown(controller.dispose);

      final error = await controller.save(
        username: 'Yih',
        bio: 'bio',
        currentProfileAsset: defaultProfileAsset,
        photoUpload: ProfilePictureUpload(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/png',
          fileName: 'me.png',
        ),
      );

      expect(error, isNull);
      expect(repository.uploadCalled, isTrue);
      expect(repository.lastSavedAvatar, 'https://example.com/avatar.jpg');
    });

    test('maps a save failure to the error state and returns a message',
        () async {
      final repository = FakeProfileRepository()
        ..saveError = StateError('boom');
      final controller = EditProfileController(repository);
      await controller.load();
      addTearDown(controller.dispose);

      final error = await controller.save(username: 'Yih', bio: 'bio');

      expect(error, contains('could not save your profile'));
      expect(controller.state.status, ProfileStatus.error);
    });
  });
}

class FakeProfileRepository implements ProfileRepository {
  Object? loadError;
  Object? saveError;
  bool uploadCalled = false;
  String lastSavedUsername = '';
  String lastSavedBio = '';
  String lastSavedAvatar = '';

  CustomerProfile profile = const CustomerProfile(
    username: 'Yih Loong',
    email: 'yl@makanspot.my',
    bio: 'Sedap hunter',
    profileAsset: defaultProfileAsset,
    profileTitle: 'Hidden Gem Hunter',
    role: 'admin',
    accountStatus: 'active',
    communityScore: 185,
  );

  @override
  Future<ProfileData> loadProfile() async {
    if (loadError != null) {
      throw loadError!;
    }
    return ProfileData(
      profile: profile,
      visits: 2,
      reviews: 2,
      cuisines: 2,
      earnedBadges: const ['First Bite'],
    );
  }

  @override
  Future<CustomerProfile> saveProfile({
    required String username,
    required String bio,
    required String profileAsset,
  }) async {
    if (saveError != null) {
      throw saveError!;
    }
    lastSavedUsername = username;
    lastSavedBio = bio;
    lastSavedAvatar = profileAsset;
    profile = profile.copyWith(
      username: username,
      bio: bio,
      profileAsset: profileAsset,
    );
    return profile;
  }

  @override
  Future<String> uploadProfilePicture(ProfilePictureUpload upload) async {
    uploadCalled = true;
    return 'https://example.com/avatar.jpg';
  }
}