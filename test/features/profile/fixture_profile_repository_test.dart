import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:makanspot/features/profile/models/fixture_profile_repository.dart';
import 'package:makanspot/features/profile/models/profile_models.dart';

void main() {
  group('FixtureProfileRepository', () {
    test('loads the seeded profile data', () async {
      final repository = FixtureProfileRepository();

      final data = await repository.loadProfile();

      expect(data.profile.username, 'Yih Loong');
      expect(data.profile.email, 'yl@makanspot.my');
      expect(data.visits, greaterThan(0));
      expect(data.earnedBadges, isNotEmpty);
    });

    test('persists edited profile fields', () async {
      final repository = FixtureProfileRepository();

      final saved = await repository.saveProfile(
        username: 'Makan Ninja',
        bio: 'New bio',
        profileAsset: 'https://fixture.makanspot.local/avatars/me.jpg',
      );

      expect(saved.username, 'Makan Ninja');
      expect(saved.bio, 'New bio');
      final reloaded = await repository.loadProfile();
      expect(reloaded.profile.username, 'Makan Ninja');
    });

    test('upload returns a public URL for the new picture', () async {
      final repository = FixtureProfileRepository();

      final url = await repository.uploadProfilePicture(
        ProfilePictureUpload(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/png',
          fileName: 'me.png',
        ),
      );

      expect(url, startsWith('https://'));
    });
  });
}