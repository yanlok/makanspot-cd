import 'community_models.dart';
import 'community_repository.dart';

class FixtureCommunityRepository implements CommunityRepository {
  FixtureCommunityRepository()
    : _posts = List.of(_seedPosts),
      _comments = List.of(_seedComments);

  final List<CommunityPost> _posts;
  final List<CommunityComment> _comments;
  int _nextPost = 1;
  int _nextComment = 1;

  @override
  Future<List<CommunityPost>> loadCommunityPosts() async {
    return List.unmodifiable(
      _posts.where((post) => post.status == 'active').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<List<CommunityPost>> loadMyPosts() async {
    return List.unmodifiable(
      _posts.where((post) => post.userId == 'demo-user').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<List<CommunityRestaurant>> loadRestaurants() async => _restaurants;

  @override
  Future<CommunityPostDetails?> loadPost(String id) async {
    final matches = _posts.where((post) => post.id == id);
    if (matches.isEmpty) {
      return null;
    }
    return CommunityPostDetails(
      post: matches.single,
      comments: List.unmodifiable(
        _comments.where((comment) => comment.postId == id),
      ),
    );
  }

  @override
  Future<CommunityPost> createPost({
    required CommunityRestaurant restaurant,
    required String reviewText,
    required int rating,
    required List<ReviewMedia> media,
  }) async {
    final post = CommunityPost(
      id: 'post-new-${_nextPost++}',
      userId: 'demo-user',
      username: 'Yih Loong',
      userAvatar: '',
      profileTitle: 'Hidden Gem Hunter',
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      restaurantImage: restaurant.imageUrl,
      reviewText: reviewText,
      rating: rating,
      mediaUrls: List.unmodifiable(media.map((item) => item.path)),
      likes: 0,
      isLiked: false,
      status: 'active',
      createdAt: DateTime(2026, 8, 3),
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<CommunityPost?> updatePost({
    required String id,
    required String reviewText,
    required int rating,
    required List<ReviewMedia> media,
  }) async {
    final index = _posts.indexWhere((post) => post.id == id);
    if (index < 0) {
      return null;
    }
    _posts[index] = _posts[index].copyWith(
      reviewText: reviewText,
      rating: rating,
      mediaUrls: List.unmodifiable(media.map((item) => item.path)),
    );
    return _posts[index];
  }

  @override
  Future<void> archivePost(String id) async {
    await _setPostStatus(id, 'archived');
  }

  @override
  Future<void> unarchivePost(String id) async {
    await _setPostStatus(id, 'active');
  }

  Future<void> _setPostStatus(String id, String status) async {
    final index = _posts.indexWhere((post) => post.id == id);
    if (index >= 0) {
      _posts[index] = _posts[index].copyWith(status: status);
    }
  }

  @override
  Future<CommunityComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    final comment = CommunityComment(
      id: 'comment-new-${_nextComment++}',
      postId: postId,
      username: 'Yih Loong',
      userAvatar: '',
      text: text,
      parentCommentId: parentCommentId,
    );
    _comments.insert(0, comment);
    return comment;
  }

  @override
  Future<CommunityPost?> toggleLike(String id) async {
    final index = _posts.indexWhere((post) => post.id == id);
    if (index < 0) {
      return null;
    }
    final post = _posts[index];
    _posts[index] = post.copyWith(
      isLiked: !post.isLiked,
      likes: post.isLiked ? post.likes - 1 : post.likes + 1,
    );
    return _posts[index];
  }
}

String _image(String id) {
  return 'https://images.unsplash.com/$id?auto=format&fit=crop&w=900&q=80';
}

final _restaurants = <CommunityRestaurant>[
  CommunityRestaurant(
    id: 'rest-1',
    name: 'Nasi Lemak Wanjo',
    cuisine: 'Malaysian',
    imageUrl: _image('photo-1563379926898-05f4575a45d8'),
  ),
  CommunityRestaurant(
    id: 'rest-2',
    name: 'Soong Kee Beef Noodles',
    cuisine: 'Chinese',
    imageUrl: _image('photo-1569718212165-3a8278d5f624'),
  ),
  CommunityRestaurant(
    id: 'rest-4',
    name: 'Brickfields Pisang Goreng',
    cuisine: 'Street Food',
    imageUrl: _image('photo-1601050690597-df0568f70950'),
  ),
];

final _seedPosts = <CommunityPost>[
  CommunityPost(
    id: 'post-demo-spam',
    userId: 'demo-user-6',
    username: 'Promo Hunter',
    userAvatar: '',
    profileTitle: 'New Member',
    restaurantId: 'rest-5',
    restaurantName: 'Murni Discovery',
    restaurantImage: '',
    reviewText:
        'Guaranteed vouchers for everyone! Message me privately and send '
        'your phone number to claim your free meal now.',
    rating: 1,
    mediaUrls: [],
    likes: 2,
    isLiked: false,
    status: 'active',
    createdAt: DateTime(2026, 7, 28, 8, 30),
  ),
  CommunityPost(
    id: 'post-1',
    userId: 'demo-user',
    username: 'Aisyah Rahman',
    userAvatar:
        'https://images.unsplash.com/photo-1531123897727-8f129e1688ce'
        '?w=200&h=200&fit=crop',
    profileTitle: 'Hidden Gem Hunter',
    restaurantId: 'rest-1',
    restaurantName: 'Nasi Lemak Wanjo',
    restaurantImage: _image('photo-1563379926898-05f4575a45d8'),
    reviewText:
        'The sambal has a lovely slow heat, the rice is fragrant with coconut, '
        'and the ayam goreng stays beautifully crunchy. The queue moves '
        'quickly, so do not let it scare you away.',
    rating: 5,
    mediaUrls: [_image('photo-1563379926898-05f4575a45d8')],
    likes: 128,
    isLiked: false,
    status: 'active',
    createdAt: DateTime(2026, 7, 27, 10),
  ),
  CommunityPost(
    id: 'post-2',
    userId: 'demo-user-2',
    username: 'Daniel Lee',
    userAvatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e'
        '?w=200&h=200&fit=crop',
    profileTitle: 'Food Explorer',
    restaurantId: 'rest-2',
    restaurantName: 'Soong Kee Beef Noodles',
    restaurantImage: _image('photo-1569718212165-3a8278d5f624'),
    reviewText:
        'Perfect comfort food for a rainy KL afternoon. The noodles are '
        'springy, the minced beef is deeply savoury, and the broth tastes like '
        'it has been simmering all morning.',
    rating: 4,
    mediaUrls: [_image('photo-1569718212165-3a8278d5f624')],
    likes: 86,
    isLiked: true,
    status: 'active',
    createdAt: DateTime(2026, 7, 26, 13, 30),
  ),
  CommunityPost(
    id: 'post-archived',
    userId: 'demo-user',
    username: 'Yih Loong',
    userAvatar: '',
    profileTitle: 'Hidden Gem Hunter',
    restaurantId: 'rest-2',
    restaurantName: 'Soong Kee Beef Noodles',
    restaurantImage: _image('photo-1569718212165-3a8278d5f624'),
    reviewText: 'A comforting bowl that deserves another visit.',
    rating: 4,
    mediaUrls: [],
    likes: 12,
    isLiked: false,
    status: 'archived',
    createdAt: DateTime(2026, 7, 20),
  ),
];

const _seedComments = <CommunityComment>[
  CommunityComment(
    id: 'comment-2',
    postId: 'post-1',
    username: 'Mei Xin',
    userAvatar: '',
    text: 'Going early tomorrow. This convinced me.',
  ),
  CommunityComment(
    id: 'comment-1',
    postId: 'post-1',
    username: 'Daniel Lee',
    userAvatar: '',
    text:
        'Agreed on the ayam goreng. It is the first thing I order every time!',
  ),
];
