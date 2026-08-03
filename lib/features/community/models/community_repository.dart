import 'community_models.dart';

abstract interface class CommunityRepository {
  Future<List<CommunityPost>> loadCommunityPosts();

  Future<List<CommunityPost>> loadMyPosts();

  Future<List<CommunityRestaurant>> loadRestaurants();

  Future<CommunityPostDetails?> loadPost(String id);

  Future<CommunityPost> createPost({
    required CommunityRestaurant restaurant,
    required String reviewText,
    required List<String> mediaUrls,
  });

  Future<CommunityPost?> updatePost({
    required String id,
    required String reviewText,
    required List<String> mediaUrls,
  });

  Future<void> archivePost(String id);

  Future<CommunityComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  });

  Future<CommunityPost?> toggleLike(String id);
}
