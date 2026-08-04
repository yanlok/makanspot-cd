import 'admin_models.dart';
import 'admin_repository.dart';

/// Deterministic prototype-like fixture data for the administrator console.
///
/// The dataset mirrors the React prototype seed: one registered user, six
/// restaurants, and four reports with pending, removed, and dismissed states.
class FixtureAdminRepository implements AdminRepository {
  FixtureAdminRepository()
    : _users = List.of(_seedUsers),
      _restaurants = List.of(_seedRestaurants),
      _reports = List.of(_seedReports),
      _posts = List.of(_seedPosts),
      _comments = List.of(_seedComments);

  final List<AdminUser> _users;
  final List<AdminRestaurant> _restaurants;
  final List<ModerationReport> _reports;
  final List<_FixturePost> _posts;
  final List<_FixtureComment> _comments;
  int _nextRestaurant = 1;

  @override
  Future<AdminDashboardData> loadDashboard() async {
    final pendingReports =
        _reports
            .where((report) => report.status == ReportStatus.pending)
            .toList()
          ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return AdminDashboardData(
      userCount: _users.length,
      restaurantCount: _restaurants.length,
      postCount: _posts.length,
      commentCount: _comments.length,
      pendingReportCount: pendingReports.length,
      recentReports: List.unmodifiable(pendingReports.take(5)),
    );
  }

  @override
  Future<List<AdminUser>> loadUsers() async {
    return List.unmodifiable(_users);
  }

  @override
  Future<AdminUser?> loadUser(String id) async {
    final matches = _users.where((user) => user.id == id);
    if (matches.isEmpty) {
      return null;
    }
    return matches.single;
  }

  @override
  Future<AdminUser?> updateUser({
    required String id,
    required String username,
    required String profileTitle,
    required int communityScore,
  }) async {
    final index = _users.indexWhere((user) => user.id == id);
    if (index < 0) {
      return null;
    }
    _users[index] = _users[index].copyWith(
      username: username,
      profileTitle: profileTitle,
      communityScore: communityScore,
    );
    return _users[index];
  }

  @override
  Future<AdminUser?> setUserAccountStatus(
    String id,
    AdminAccountStatus status,
  ) async {
    final index = _users.indexWhere((user) => user.id == id);
    if (index < 0) {
      return null;
    }
    _users[index] = _users[index].copyWith(accountStatus: status);
    return _users[index];
  }

  @override
  Future<List<AdminRestaurant>> loadRestaurants() async {
    return List.unmodifiable(_restaurants);
  }

  @override
  Future<AdminRestaurant?> loadRestaurant(String id) async {
    final matches = _restaurants.where((restaurant) => restaurant.id == id);
    if (matches.isEmpty) {
      return null;
    }
    return matches.single;
  }

  @override
  Future<AdminRestaurant> createRestaurant(AdminRestaurantDraft draft) async {
    final restaurant = _restaurantFromDraft(
      id: 'rest-new-${_nextRestaurant++}',
      draft: draft,
    );
    _restaurants.insert(0, restaurant);
    return restaurant;
  }

  @override
  Future<AdminRestaurant?> updateRestaurant(
    String id,
    AdminRestaurantDraft draft,
  ) async {
    final index = _restaurants.indexWhere((restaurant) => restaurant.id == id);
    if (index < 0) {
      return null;
    }
    final updated = _restaurantFromDraft(id: id, draft: draft);
    _restaurants[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteRestaurant(String id) async {
    _restaurants.removeWhere((restaurant) => restaurant.id == id);
  }

  @override
  Future<List<ModerationReport>> loadReports() async {
    return List.unmodifiable(_reports);
  }

  @override
  Future<ModerationReport?> loadReport(String id) async {
    final matches = _reports.where((report) => report.id == id);
    if (matches.isEmpty) {
      return null;
    }
    return matches.single;
  }

  @override
  Future<ReportedContent?> loadReportedContent(ModerationReport report) async {
    if (report.contentType == ReportContentType.post) {
      final matches = _posts.where((post) => post.id == report.contentId);
      if (matches.isEmpty) {
        return null;
      }
      final post = matches.single;
      return ReportedContent(
        username: post.username,
        restaurantName: post.restaurantName,
        text: post.reviewText,
        mediaUrls: List.unmodifiable(post.mediaUrls),
      );
    }
    final matches = _comments.where(
      (comment) => comment.id == report.contentId,
    );
    if (matches.isEmpty) {
      return null;
    }
    final comment = matches.single;
    return ReportedContent(
      username: comment.username,
      text: comment.text,
      mediaUrls: const [],
    );
  }

  @override
  Future<ModerationReport?> resolveReport({
    required String id,
    required ReportStatus status,
    String? removalReason,
  }) async {
    final index = _reports.indexWhere((report) => report.id == id);
    if (index < 0) {
      return null;
    }
    if (status == ReportStatus.removed &&
        _reports[index].contentType == ReportContentType.comment) {
      // Removed comments disappear from public view, mirroring the prototype.
      _comments.removeWhere(
        (comment) => comment.id == _reports[index].contentId,
      );
    }
    _reports[index] = _reports[index].copyWith(
      status: status,
      removalReason: status == ReportStatus.removed ? removalReason : null,
    );
    return _reports[index];
  }

  AdminRestaurant _restaurantFromDraft({
    required String id,
    required AdminRestaurantDraft draft,
  }) {
    return AdminRestaurant(
      id: id,
      name: draft.name,
      cuisine: draft.cuisine,
      address: draft.address,
      imageUrl: draft.imageUrl,
      operatingHours: draft.operatingHours,
      contact: draft.contact,
      budget: draft.budget,
      description: draft.description,
      sourcePlatform: draft.sourcePlatform,
      isVerified: draft.isVerified,
      rating: draft.rating,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }
}

String _image(String id) {
  return 'https://images.unsplash.com/$id?auto=format&fit=crop&w=900&q=80';
}

final _seedUsers = <AdminUser>[
  AdminUser(
    id: 'demo-user',
    username: 'Yih Loong',
    email: 'yl@makanspot.my',
    profilePictureUrl: 'assets/images/default_icon.jpg',
    profileTitle: 'Hidden Gem Hunter',
    communityScore: 185,
    accountStatus: AdminAccountStatus.active,
  ),
];

final _seedRestaurants = <AdminRestaurant>[
  AdminRestaurant(
    id: 'rest-1',
    name: 'Nasi Lemak Wanjo',
    cuisine: 'Malaysian',
    rating: 4.7,
    budget: 'Low',
    address: '8, Jalan Raja Muda Musa, Kampung Baru, Kuala Lumpur',
    description:
        'A much-loved Kampung Baru stop for fragrant nasi lemak and ayam '
        'goreng berempah.',
    operatingHours: '7:00 AM – 12:00 AM',
    contact: '+60 3-2698 2233',
    latitude: 3.1617,
    longitude: 101.7048,
    imageUrl: _image('photo-1563379926898-05f4575a45d8'),
    sourcePlatform: 'Manual',
    isVerified: false,
  ),
  AdminRestaurant(
    id: 'rest-2',
    name: 'Soong Kee Beef Noodles',
    cuisine: 'Chinese',
    rating: 4.5,
    budget: 'Medium',
    address: '86, Jalan Tun H S Lee, Kuala Lumpur',
    description:
        'Springy noodles, comforting beef broth and a classic KL '
        'coffee-shop atmosphere.',
    operatingHours: '7:30 AM – 4:00 PM',
    contact: '+60 3-2078 3536',
    latitude: 3.1459,
    longitude: 101.7003,
    imageUrl: _image('photo-1569718212165-3a8278d5f624'),
    sourcePlatform: 'Manual',
    isVerified: false,
  ),
  AdminRestaurant(
    id: 'rest-3',
    name: 'Restoran Rebung',
    cuisine: 'Malay',
    rating: 4.6,
    budget: 'Medium',
    address: '5-2, Jalan Jalal, Off Jalan Raja Abdullah, Kuala Lumpur',
    description:
        'Traditional Malay dishes served buffet-style in a warm, leafy '
        'setting.',
    operatingHours: '11:00 AM – 5:00 PM',
    contact: '+60 3-2602 3630',
    latitude: 3.1648,
    longitude: 101.7042,
    imageUrl: _image('photo-1547592180-85f173990554'),
    sourcePlatform: 'Manual',
    isVerified: false,
  ),
  AdminRestaurant(
    id: 'rest-4',
    name: 'Brickfields Pisang Goreng',
    cuisine: 'Street Food',
    rating: 4.4,
    budget: 'Low',
    address: 'Jalan Tun Sambanthan, Brickfields, Kuala Lumpur',
    description:
        'Crisp, hot banana fritters that make an ideal afternoon snack.',
    operatingHours: '10:00 AM – 7:00 PM',
    contact: '',
    latitude: 3.1307,
    longitude: 101.6869,
    imageUrl: _image('photo-1601050690597-df0568f70950'),
    sourcePlatform: 'Manual',
    isVerified: false,
  ),
  AdminRestaurant(
    id: 'rest-5',
    name: 'Murni Discovery',
    cuisine: 'Mamak',
    rating: 4.3,
    budget: 'Low',
    address: '2, Jalan 21/19, Sea Park, Petaling Jaya',
    description:
        'Generous mamak favourites, toast and colourful drinks for supper.',
    operatingHours: '4:00 PM – 2:00 AM',
    contact: '+60 3-7877 7866',
    latitude: 3.1050,
    longitude: 101.6385,
    imageUrl: _image('photo-1552566626-52f8b828add9'),
    sourcePlatform: 'Manual',
    isVerified: false,
  ),
  AdminRestaurant(
    id: 'rest-6',
    name: 'Inside Scoop',
    cuisine: 'Desserts',
    rating: 4.6,
    budget: 'Medium',
    address: 'Jalan Telawi, Bangsar Baru, Kuala Lumpur',
    description:
        'Small-batch Malaysian ice cream in inventive rotating flavours.',
    operatingHours: '12:00 PM – 11:00 PM',
    contact: '',
    latitude: 3.1291,
    longitude: 101.6710,
    imageUrl: _image('photo-1501443762994-82bd5dace89a'),
    sourcePlatform: 'Manual',
    isVerified: false,
  ),
];

final _seedPosts = <_FixturePost>[
  _FixturePost(
    id: 'post-demo-spam',
    username: 'Promo Hunter',
    restaurantName: 'Murni Discovery',
    reviewText:
        'Guaranteed vouchers for everyone! Message me privately and send '
        'your phone number to claim your free meal now.',
    mediaUrls: const [],
  ),
  _FixturePost(
    id: 'post-1',
    username: 'Aisyah Rahman',
    restaurantName: 'Nasi Lemak Wanjo',
    reviewText:
        'The sambal has a lovely slow heat, the rice is fragrant with '
        'coconut, and the ayam goreng stays beautifully crunchy.',
    mediaUrls: [_image('photo-1563379926898-05f4575a45d8')],
  ),
  _FixturePost(
    id: 'post-2',
    username: 'Daniel Lee',
    restaurantName: 'Soong Kee Beef Noodles',
    reviewText:
        'Perfect comfort food for a rainy KL afternoon. The noodles are '
        'springy and the broth tastes like it has been simmering all morning.',
    mediaUrls: [_image('photo-1569718212165-3a8278d5f624')],
  ),
  _FixturePost(
    id: 'post-3',
    username: 'Mei Xin',
    restaurantName: 'Brickfields Pisang Goreng',
    reviewText:
        'Crispy outside, soft and naturally sweet inside. Best eaten '
        'immediately while it is still hot.',
    mediaUrls: [_image('photo-1601050690597-df0568f70950')],
  ),
  _FixturePost(
    id: 'post-4',
    username: 'Arjun Nair',
    restaurantName: 'Murni Discovery',
    reviewText:
        'Huge portions, cheerful mamak energy and enough menu choices for '
        'the whole table.',
    mediaUrls: [_image('photo-1552566626-52f8b828add9')],
  ),
  _FixturePost(
    id: 'post-5',
    username: 'Sofia Ahmad',
    restaurantName: 'Inside Scoop',
    reviewText:
        'The teh tarik ice cream tastes unmistakably local without being '
        'too sweet.',
    mediaUrls: [_image('photo-1501443762994-82bd5dace89a')],
  ),
  _FixturePost(
    id: 'post-demo-removed',
    username: 'KL Food Deals',
    restaurantName: 'Restoran Rebung',
    reviewText:
        'This post previously contained repeated promotional links and has '
        'been removed from public view.',
    mediaUrls: const [],
  ),
];

final _seedComments = <_FixtureComment>[
  _FixtureComment(
    id: 'comment-1',
    username: 'Daniel Lee',
    text:
        'Agreed on the ayam goreng. It is the first thing I order every time!',
  ),
  _FixtureComment(
    id: 'comment-2',
    username: 'Mei Xin',
    text: 'Going early tomorrow. This convinced me.',
  ),
  _FixtureComment(
    id: 'comment-demo-abuse',
    username: 'Anonymous Foodie',
    text:
        'Only an idiot would recommend this place. Your reviews are '
        'completely useless.',
  ),
];

final _seedReports = <ModerationReport>[
  ModerationReport(
    id: 'report-demo-post-pending',
    contentType: ReportContentType.post,
    contentId: 'post-demo-spam',
    contentPreview:
        'Guaranteed vouchers for everyone! Message me privately and send '
        'your phone number...',
    contentOwner: 'Promo Hunter',
    reporterName: 'Aisyah Rahman',
    reason: 'Spam or misleading promotion',
    additionalInfo:
        'The post asks users to share personal contact information to claim '
        'a suspicious offer.',
    status: ReportStatus.pending,
    reportCount: 4,
    createdDate: DateTime(2026, 7, 28, 9, 5),
  ),
  ModerationReport(
    id: 'report-demo-comment-pending',
    contentType: ReportContentType.comment,
    contentId: 'comment-demo-abuse',
    contentPreview:
        'Only an idiot would recommend this place. Your reviews are '
        'completely useless.',
    contentOwner: 'Anonymous Foodie',
    reporterName: 'Daniel Lee',
    reason: 'Harassment or abusive language',
    additionalInfo:
        'The comment attacks another community member instead of discussing '
        'the restaurant.',
    status: ReportStatus.pending,
    reportCount: 3,
    createdDate: DateTime(2026, 7, 28, 11, 10),
  ),
  ModerationReport(
    id: 'report-demo-post-dismissed',
    contentType: ReportContentType.post,
    contentId: 'post-3',
    contentPreview: 'Crispy outside, soft and naturally sweet inside...',
    contentOwner: 'Mei Xin',
    reporterName: 'Arjun Nair',
    reason: 'Misleading information',
    additionalInfo:
        'Review found to be a genuine personal opinion with no policy '
        'violation.',
    status: ReportStatus.dismissed,
    reportCount: 1,
    createdDate: DateTime(2026, 7, 26, 14, 20),
  ),
  ModerationReport(
    id: 'report-demo-post-removed',
    contentType: ReportContentType.post,
    contentId: 'post-demo-removed',
    contentPreview: 'Repeated promotional links and unsolicited advertising.',
    contentOwner: 'KL Food Deals',
    reporterName: 'Sofia Ahmad',
    reason: 'Spam or misleading promotion',
    additionalInfo:
        'Multiple community members reported repeated advertising links.',
    status: ReportStatus.removed,
    removalReason:
        'Repeated unsolicited advertising and suspicious promotional links.',
    reportCount: 6,
    createdDate: DateTime(2026, 7, 25, 10),
  ),
];

class _FixturePost {
  const _FixturePost({
    required this.id,
    required this.username,
    required this.restaurantName,
    required this.reviewText,
    required this.mediaUrls,
  });

  final String id;
  final String username;
  final String restaurantName;
  final String reviewText;
  final List<String> mediaUrls;
}

class _FixtureComment {
  const _FixtureComment({
    required this.id,
    required this.username,
    required this.text,
  });

  final String id;
  final String username;
  final String text;
}
