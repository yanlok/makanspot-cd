import 'admin_models.dart';
import 'admin_repository.dart';

/// Deterministic prototype-like fixture data for the administrator console.
class FixtureAdminRepository implements AdminRepository {
  FixtureAdminRepository()
    : _users = List.of(_seedUsers),
      _restaurants = List.of(_seedRestaurants),
      _groups = _seedGroups(),
      _posts = List.of(_seedPosts),
      _comments = List.of(_seedComments);

  final List<AdminUser> _users;
  final List<AdminRestaurant> _restaurants;
  final List<ReportedContentGroup> _groups;
  final List<_FixturePost> _posts;
  final List<_FixtureComment> _comments;
  int _nextRestaurant = 1;

  @override
  Future<AdminDashboardData> loadDashboard() async {
    final pendingGroups = _groups.where((g) => !g.isRemoved).toList()
      ..sort(
        (a, b) =>
            b.reports.first.createdDate.compareTo(a.reports.first.createdDate),
      );
    return AdminDashboardData(
      userCount: _users.length,
      restaurantCount: _restaurants.length,
      postCount: _posts.length,
      commentCount: _comments.length,
      pendingReportCount: pendingGroups.length,
      recentReports: List.unmodifiable(pendingGroups.take(5)),
    );
  }

  @override
  Future<List<AdminUser>> loadUsers() async => List.unmodifiable(_users);

  @override
  Future<AdminUser?> loadUser(String id) async {
    final matches = _users.where((u) => u.id == id);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<AdminUser?> updateUser({
    required String id,
    required String username,
    required String profileTitle,
    required int communityScore,
  }) async {
    final i = _users.indexWhere((u) => u.id == id);
    if (i < 0) return null;
    _users[i] = _users[i].copyWith(
      username: username,
      profileTitle: profileTitle,
      communityScore: communityScore,
    );
    return _users[i];
  }

  @override
  Future<AdminUser?> setUserAccountStatus(
    String id,
    AdminAccountStatus status,
  ) async {
    final i = _users.indexWhere((u) => u.id == id);
    if (i < 0) return null;
    _users[i] = _users[i].copyWith(accountStatus: status);
    return _users[i];
  }

  @override
  Future<List<AdminRestaurant>> loadRestaurants() async =>
      List.unmodifiable(_restaurants);

  @override
  Future<AdminRestaurant?> loadRestaurant(String id) async {
    final matches = _restaurants.where((r) => r.id == id);
    return matches.isEmpty ? null : matches.single;
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
    final i = _restaurants.indexWhere((r) => r.id == id);
    if (i < 0) return null;
    _restaurants[i] = _restaurantFromDraft(id: id, draft: draft);
    return _restaurants[i];
  }

  @override
  Future<void> deleteRestaurant(String id) async {
    _restaurants.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<ReportedContentGroup>> loadReportedContentGroups() async =>
      List.unmodifiable(_groups);

  @override
  Future<ReportedContentGroup?> loadReportedContentGroup(
    String contentId,
  ) async {
    final matches = _groups.where((g) => g.contentId == contentId);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<ReportedContent?> loadReportedContent(
    ReportedContentGroup group,
  ) async {
    if (group.contentType == ReportContentType.post) {
      final matches = _posts.where((p) => p.id == group.contentId);
      if (matches.isEmpty) return null;
      final post = matches.single;
      return ReportedContent(
        username: post.username,
        restaurantName: post.restaurantName,
        text: post.reviewText,
        mediaUrls: List.unmodifiable(post.mediaUrls),
      );
    }
    final matches = _comments.where((c) => c.id == group.contentId);
    if (matches.isEmpty) return null;
    final comment = matches.single;
    return ReportedContent(
      username: comment.username,
      text: comment.text,
      mediaUrls: const [],
    );
  }

  @override
  Future<void> removeContent(String contentId) async {
    final i = _groups.indexWhere((g) => g.contentId == contentId);
    if (i >= 0) {
      _groups[i] = _groups[i].copyWith(isRemoved: true);
    }
  }

  @override
  Future<void> dismissReports(String contentId) async {
    _groups.removeWhere((g) => g.contentId == contentId);
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
    description: 'A much-loved Kampung Baru stop for fragrant nasi lemak.',
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
    description: 'Springy noodles and comforting beef broth.',
    operatingHours: '7:30 AM – 4:00 PM',
    contact: '+60 3-2078 3536',
    latitude: 3.1459,
    longitude: 101.7003,
    imageUrl: _image('photo-1569718212165-3a8278d5f624'),
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
    id: 'post-3',
    username: 'Mei Xin',
    restaurantName: 'Brickfields Pisang Goreng',
    reviewText: 'Crispy outside, soft and naturally sweet inside.',
    mediaUrls: [_image('photo-1601050690597-df0568f70950')],
  ),
  _FixturePost(
    id: 'post-demo-removed',
    username: 'KL Food Deals',
    restaurantName: 'Restoran Rebung',
    reviewText: 'This post previously contained repeated promotional links.',
    mediaUrls: const [],
  ),
];

final _seedComments = <_FixtureComment>[
  _FixtureComment(
    id: 'comment-demo-abuse',
    username: 'Anonymous Foodie',
    text:
        'Only an idiot would recommend this place. Your reviews are '
        'completely useless.',
  ),
  _FixtureComment(
    id: 'comment-1',
    username: 'Daniel Lee',
    text: 'Agreed on the ayam goreng!',
  ),
];

List<ReportedContentGroup> _seedGroups() {
  return [
    // Pending: 2 reports on same post
    ReportedContentGroup(
      contentId: 'post-demo-spam',
      contentType: ReportContentType.post,
      contentPreview: 'Guaranteed vouchers for everyone!...',
      contentOwner: 'Promo Hunter',
      isRemoved: false,
      reports: [
        ModerationReport(
          id: 'report-1',
          reporterName: 'Aisyah Rahman',
          reason: 'Spam or misleading promotion',
          additionalInfo: 'Asks users to share personal contact info.',
          createdDate: DateTime(2026, 7, 28, 9, 5),
        ),
        ModerationReport(
          id: 'report-2',
          reporterName: 'Daniel Lee',
          reason: 'Spam or misleading promotion',
          additionalInfo: 'Looks like a phishing attempt.',
          createdDate: DateTime(2026, 7, 28, 11, 10),
        ),
      ],
    ),
    // Pending: comment report
    ReportedContentGroup(
      contentId: 'comment-demo-abuse',
      contentType: ReportContentType.comment,
      contentPreview: 'Only an idiot would recommend this place...',
      contentOwner: 'Anonymous Foodie',
      isRemoved: false,
      reports: [
        ModerationReport(
          id: 'report-3',
          reporterName: 'Daniel Lee',
          reason: 'Harassment or abusive language',
          additionalInfo: 'Attacks another community member.',
          createdDate: DateTime(2026, 7, 29, 8, 30),
        ),
      ],
    ),
    // Pending: single report on post
    ReportedContentGroup(
      contentId: 'post-3',
      contentType: ReportContentType.post,
      contentPreview: 'Crispy outside, soft and naturally sweet inside...',
      contentOwner: 'Mei Xin',
      isRemoved: false,
      reports: [
        ModerationReport(
          id: 'report-4',
          reporterName: 'Arjun Nair',
          reason: 'Misleading information',
          additionalInfo: 'Review seems inaccurate.',
          createdDate: DateTime(2026, 7, 26, 14, 20),
        ),
      ],
    ),
    // Removed: post was hidden by admin
    ReportedContentGroup(
      contentId: 'post-demo-removed',
      contentType: ReportContentType.post,
      contentPreview: 'Repeated promotional links...',
      contentOwner: 'KL Food Deals',
      isRemoved: true,
      reports: [
        ModerationReport(
          id: 'report-5',
          reporterName: 'Sofia Ahmad',
          reason: 'Spam or misleading promotion',
          additionalInfo: 'Multiple reports of advertising links.',
          createdDate: DateTime(2026, 7, 25, 10),
        ),
      ],
    ),
  ];
}

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
