import 'community_models.dart';

abstract interface class CommunityRepository {
  Future<List<CommunityPost>> loadCommunityPosts();

  Future<List<CommunityPost>> loadMyPosts();

  Future<List<CommunityRestaurant>> loadRestaurants();

  Future<CommunityPostDetails?> loadPost(String id);

  Future<CommunityPost> createPost({
    required CommunityRestaurant restaurant,
    required String reviewText,
    required int rating,
    required List<ReviewMedia> media,
  });

  Future<CommunityPost?> updatePost({
    required String id,
    required String reviewText,
    required int rating,
    required List<ReviewMedia> media,
  });

  Future<void> archivePost(String id);

  Future<CommunityComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  });

  Future<CommunityPost?> toggleLike(String id);
}
