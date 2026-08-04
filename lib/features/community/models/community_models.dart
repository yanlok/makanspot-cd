class CommunityRestaurant {
  const CommunityRestaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String cuisine;
  final String imageUrl;
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.profileTitle,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImage,
    required this.reviewText,
    required this.rating,
    required this.mediaUrls,
    required this.likes,
    required this.isLiked,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String username;
  final String userAvatar;
  final String profileTitle;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String reviewText;
  final int rating;
  final List<String> mediaUrls;
  final int likes;
  final bool isLiked;
  final String status;
  final DateTime createdAt;

  CommunityPost copyWith({
    String? reviewText,
    int? rating,
    List<String>? mediaUrls,
    int? likes,
    bool? isLiked,
    String? status,
  }) {
    return CommunityPost(
      id: id,
      userId: userId,
      username: username,
      userAvatar: userAvatar,
      profileTitle: profileTitle,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      restaurantImage: restaurantImage,
      reviewText: reviewText ?? this.reviewText,
      rating: rating ?? this.rating,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

enum ReviewMediaType { image, video }

class ReviewMedia {
  const ReviewMedia({
    required this.path,
    required this.type,
    this.isLocal = false,
  });

  final String path;
  final ReviewMediaType type;
  final bool isLocal;
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.username,
    required this.userAvatar,
    required this.text,
    this.parentCommentId,
  });

  final String id;
  final String postId;
  final String username;
  final String userAvatar;
  final String text;
  final String? parentCommentId;
}

class CommunityPostDetails {
  const CommunityPostDetails({required this.post, required this.comments});

  final CommunityPost post;
  final List<CommunityComment> comments;
}
