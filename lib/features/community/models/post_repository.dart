import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/models/post_model.dart';

class PostRepository {
  final SupabaseClient _supabase;
  PostRepository(this._supabase);

  Future<List<PostModel>> getFeed({int limit = 10, int offset = 0}) async {
    final userId = _supabase.auth.currentUser?.id;
    final data = await _supabase
        .from('posts')
        .select('''
          *,
          users!posts_user_id_fkey(username, avatar_url),
          restaurants!posts_restaurant_id_fkey(name),
          likes!left(user_id),
          bookmarks!left(user_id)
        ''')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((json) {
      final likes = json['likes'] as List?;
      final bookmarks = json['bookmarks'] as List?;
      final isLiked = userId != null && likes != null && likes.any((l) => l['user_id'] == userId);
      final isBookmarked = userId != null && bookmarks != null && bookmarks.any((b) => b['user_id'] == userId);
      return PostModel.fromJson({
        ...json,
        'username': json['users']?['username'],
        'userAvatarUrl': json['users']?['avatar_url'],
        'restaurantName': json['restaurants']?['name'],
        'isLiked': isLiked,
        'isBookmarked': isBookmarked,
      });
    }).toList();
  }

  Future<void> createPost({required String content, List<String>? mediaUrls, String? restaurantId}) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('posts').insert({'user_id': userId, 'content': content, 'media_urls': mediaUrls, 'restaurant_id': restaurantId});
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    final userId = _supabase.auth.currentUser!.id;
    if (isLiked) {
      await _supabase.from('likes').delete().match({'post_id': postId, 'user_id': userId});
    } else {
      await _supabase.from('likes').insert({'post_id': postId, 'user_id': userId});
    }
  }

  Future<void> addComment(String postId, String content) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('comments').insert({'post_id': postId, 'user_id': userId, 'content': content});
  }

  Future<void> reportPost(String postId, String reason) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('reports').insert({'post_id': postId, 'reporter_id': userId, 'reason': reason});
  }
}
