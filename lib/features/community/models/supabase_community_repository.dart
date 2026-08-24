import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_models.dart';
import 'community_repository.dart';

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._client);

  final SupabaseClient _client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to publish a review.');
    }
    return user;
  }

  static const _postSelect =
      'id,user_id,restaurant_id,content,rating,media_urls,status,created_at,'
      'users!posts_user_id_fkey(username,avatar_url,community_score),'
      'restaurants!posts_restaurant_id_fkey(name,restaurant_images(image_url,is_primary)),'
      'likes(user_id),comments(id)';

  @override
  Future<List<CommunityPost>> loadCommunityPosts() async {
    final rows = await _client
        .from('posts')
        .select(_postSelect)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return rows.map<CommunityPost>(_postFromRow).toList(growable: false);
  }

  @override
  Future<List<CommunityPost>> loadMyPosts() async {
    final rows = await _client
        .from('posts')
        .select(_postSelect)
        .eq('user_id', _user.id)
        .order('created_at', ascending: false);
    return rows.map<CommunityPost>(_postFromRow).toList(growable: false);
  }

  @override
  Future<List<CommunityRestaurant>> loadRestaurants() async {
    final rows = await _client
        .from('restaurants')
        // Keep this query independent of optional category/image relationships.
        // A restaurant should still be reviewable before enrichment is complete.
        .select('id,name')
        .eq('is_approved', true)
        .order('name');
    return rows
        .map<CommunityRestaurant>(
          (row) => CommunityRestaurant(
            id: row['id'].toString(),
            name: row['name']?.toString() ?? 'Restaurant',
            cuisine: 'Restaurant',
            imageUrl: '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CommunityPostDetails?> loadPost(String id) async {
    final row = await _client
        .from('posts')
        .select(_postSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final comments = await _client
        .from('comments')
        .select(
          'id,post_id,content,user_id,parent_comment_id,users(username,avatar_url)',
        )
        .eq('post_id', id)
        .order('created_at');
    return CommunityPostDetails(
      post: _postFromRow(row),
      comments: comments
          .map<CommunityComment>((item) {
            final user = item['users'] as Map? ?? const {};
            return CommunityComment(
              id: item['id'].toString(),
              postId: item['post_id'].toString(),
              username: user['username']?.toString() ?? 'Food explorer',
              userAvatar: user['avatar_url']?.toString() ?? '',
              text: item['content']?.toString() ?? '',
              parentCommentId: item['parent_comment_id']?.toString(),
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Future<CommunityPost> createPost({
    required CommunityRestaurant restaurant,
    required String reviewText,
    required int rating,
    required List<ReviewMedia> media,
  }) async {
    final urls = await _uploadMedia(media);
    final row = await _client
        .from('posts')
        .insert({
          'user_id': _user.id,
          'restaurant_id': int.parse(restaurant.id),
          'content': reviewText,
          'rating': rating,
          'media_urls': urls,
          'status': 'active',
        })
        .select(_postSelect)
        .single();
    return _postFromRow(row);
  }

  @override
  Future<CommunityPost?> updatePost({
    required String id,
    required String reviewText,
    required int rating,
    required List<ReviewMedia> media,
  }) async {
    final urls = await _uploadMedia(media);
    final row = await _client
        .from('posts')
        .update({
          'content': reviewText,
          'rating': rating,
          'media_urls': urls,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _user.id)
        .select(_postSelect)
        .maybeSingle();
    return row == null ? null : _postFromRow(row);
  }

  @override
  Future<void> archivePost(String id) async {
    await _client
        .from('posts')
        .update({
          'status': 'archived',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _user.id);
  }

  @override
  Future<void> unarchivePost(String id) async {
    await _client
        .from('posts')
        .update({
          'status': 'active',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _user.id);
  }

  @override
  Future<CommunityComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    final row = await _client
        .from('comments')
        .insert({
          'post_id': int.parse(postId),
          'user_id': _user.id,
          'content': text,
          'parent_comment_id': parentCommentId == null
              ? null
              : int.parse(parentCommentId),
        })
        .select('id,post_id,content,parent_comment_id')
        .single();
    final metadata = _user.userMetadata ?? const {};
    return CommunityComment(
      id: row['id'].toString(),
      postId: row['post_id'].toString(),
      username: metadata['username']?.toString() ?? 'You',
      userAvatar: metadata['avatar_url']?.toString() ?? '',
      text: row['content'].toString(),
      parentCommentId: row['parent_comment_id']?.toString(),
    );
  }

  @override
  Future<CommunityPost?> toggleLike(String id) async {
    final existing = await _client
        .from('likes')
        .select('post_id')
        .eq('post_id', id)
        .eq('user_id', _user.id)
        .maybeSingle();
    if (existing == null) {
      await _client.from('likes').insert({
        'post_id': int.parse(id),
        'user_id': _user.id,
      });
    } else {
      await _client
          .from('likes')
          .delete()
          .eq('post_id', id)
          .eq('user_id', _user.id);
    }
    final row = await _client
        .from('posts')
        .select(_postSelect)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _postFromRow(row);
  }

  Future<List<String>> _uploadMedia(List<ReviewMedia> media) async {
    final result = <String>[];
    for (final item in media) {
      if (!item.isLocal) {
        result.add(item.path);
        continue;
      }
      final extension = item.path.split('.').last.toLowerCase();
      final objectPath =
          '${_user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage
          .from('community-media')
          .upload(
            objectPath,
            File(item.path),
            fileOptions: const FileOptions(upsert: false),
          );
      result.add(
        _client.storage.from('community-media').getPublicUrl(objectPath),
      );
    }
    return result;
  }

  CommunityPost _postFromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map? ?? const {};
    final restaurant = row['restaurants'] as Map? ?? const {};
    final likes = row['likes'] as List? ?? const [];
    final comments = row['comments'] as List? ?? const [];
    final currentUserId = _client.auth.currentUser?.id;
    return CommunityPost(
      id: row['id'].toString(),
      userId: row['user_id'].toString(),
      username: user['username']?.toString() ?? 'Food explorer',
      userAvatar: user['avatar_url']?.toString() ?? '',
      profileTitle: _profileTitle(user['community_score'] as int? ?? 0),
      restaurantId: row['restaurant_id']?.toString() ?? '',
      restaurantName: restaurant['name']?.toString() ?? 'Restaurant',
      restaurantImage: _primaryImage(restaurant['restaurant_images']),
      reviewText: row['content']?.toString() ?? '',
      rating: row['rating'] as int? ?? 0,
      mediaUrls: List<String>.from(row['media_urls'] as List? ?? const []),
      likes: likes.length,
      commentCount: comments.length,
      isLiked:
          currentUserId != null &&
          likes.any((like) => (like as Map)['user_id'] == currentUserId),
      status: row['status']?.toString() ?? 'active',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

String _primaryImage(Object? value) {
  final images = value as List? ?? const [];
  if (images.isEmpty) return '';
  final primary = images.cast<Map>().where(
    (item) => item['is_primary'] == true,
  );
  final selected = primary.isNotEmpty ? primary.first : images.first as Map;
  return selected['image_url']?.toString() ?? '';
}

String _profileTitle(int score) {
  if (score >= 500) return 'Makan Legend';
  if (score >= 100) return 'Hidden Gem Hunter';
  return 'Food Explorer';
}
