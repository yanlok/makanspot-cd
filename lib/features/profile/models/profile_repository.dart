import 'profile_models.dart';

abstract interface class ProfileRepository {
  Future<ProfileData> loadProfile();

  Future<List<DemoRegisteredAccount>> loadDemoRegisteredAccounts();

  Future<CustomerProfile> saveProfile({
    required String username,
    required String bio,
    required String profileAsset,
  });
}
