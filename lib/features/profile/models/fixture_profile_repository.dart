import 'profile_models.dart';
import 'profile_repository.dart';

class FixtureProfileRepository implements ProfileRepository {
  CustomerProfile _profile = const CustomerProfile(
    username: 'Yih Loong',
    email: 'yl@makanspot.my',
    bio:
        'Sedap hunter exploring hidden gems around Klang Valley. Love a good '
        'roti canai at 3am.',
    profileAsset: 'assets/images/default_icon.jpg',
    profileTitle: 'Hidden Gem Hunter',
    role: 'admin',
    accountStatus: 'active',
    communityScore: 185,
  );

  @override
  Future<ProfileData> loadProfile() async {
    return ProfileData(
      profile: _profile,
      visits: 2,
      reviews: 2,
      cuisines: 2,
      earnedBadges: const ['First Bite', 'Review Rookie'],
    );
  }

  @override
  Future<CustomerProfile> saveProfile({
    required String username,
    required String bio,
    required String profileAsset,
  }) async {
    _profile = _profile.copyWith(
      username: username,
      bio: bio,
      profileAsset: profileAsset,
    );
    return _profile;
  }

  @override
  Future<String> uploadProfilePicture(ProfilePictureUpload upload) async {
    // Returns a stable fake URL so the upload flow is exercised without a
    // storage backend.
    return 'https://fixture.makanspot.local/avatars/${upload.fileName ?? 'avatar.jpg'}';
  }
}
