import 'profile_models.dart';

abstract interface class ProfileRepository {
  Future<ProfileData> loadProfile();

  /// Persists the edited [username], [bio], and avatar referenced by
  /// [profileAsset], returning the saved profile.
  Future<CustomerProfile> saveProfile({
    required String username,
    required String bio,
    required String profileAsset,
  });

  /// Uploads a profile picture and returns its public URL.
  Future<String> uploadProfilePicture(ProfilePictureUpload upload);
}