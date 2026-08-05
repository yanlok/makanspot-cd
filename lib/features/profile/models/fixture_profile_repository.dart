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

  static const List<DemoRegisteredAccount> _demoAccounts = [
    DemoRegisteredAccount(
      id: 'u-001',
      name: 'Yih Loong',
      email: 'yl@makanspot.my',
      bio: 'Sedap hunter exploring hidden gems around Klang Valley.',
      photoUrl: 'assets/images/default_icon.jpg',
      role: 'admin',
      status: 'active',
    ),
    DemoRegisteredAccount(
      id: 'u-002',
      name: 'Aina Rahman',
      email: 'aina.r@makanspot.my',
      bio: 'Weekend cafe hopper and kopi enthusiast.',
      photoUrl: 'assets/images/default_icon.jpg',
      role: 'user',
      status: 'active',
    ),
    DemoRegisteredAccount(
      id: 'u-003',
      name: 'Kelvin Ong',
      email: 'kelvin.o@makanspot.my',
      bio: 'Shares hidden hawker stalls and supper spots.',
      photoUrl: 'assets/images/default_icon.jpg',
      role: 'user',
      status: 'pending',
    ),
    DemoRegisteredAccount(
      id: 'u-004',
      name: 'Nadia Suraya',
      email: 'nadia.s@makanspot.my',
      bio: 'Food storyteller focused on local kuih and family recipes.',
      photoUrl: 'assets/images/default_icon.jpg',
      role: 'admin',
      status: 'deactivated',
    ),
  ];

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
  Future<List<DemoRegisteredAccount>> loadDemoRegisteredAccounts() async {
    return List.unmodifiable(_demoAccounts);
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
}
