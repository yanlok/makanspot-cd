class PostModel {
  final String id;
  final String userId;
  final String? username;
  final String? userAvatarUrl;
  final String? restaurantId;
  final String? restaurantName;
  final String? content;
  final List<String>? mediaUrls;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isBookmarked;
  final DateTime? createdAt;

  PostModel({
    required this.id,
    required this.userId,
    this.username,
    this.userAvatarUrl,
    this.restaurantId,
    this.restaurantName,
    this.content,
    this.mediaUrls,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'].toString(),
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      restaurantId: json['restaurant_id']?.toString(),
      restaurantName: json['restaurantName'] as String?,
      content: json['content'] as String?,
      mediaUrls: json['media_urls'] != null ? List<String>.from(json['media_urls'] as List) : null,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
