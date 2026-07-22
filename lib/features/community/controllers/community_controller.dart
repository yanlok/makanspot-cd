import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_repository.dart';
import '../../../../shared/models/post_model.dart';

final postRepositoryProvider = Provider<PostRepository>((Ref ref) {
  return PostRepository(Supabase.instance.client);
});

final communityFeedProvider = FutureProvider<List<PostModel>>((Ref ref) async {
  return ref.watch(postRepositoryProvider).getFeed();
});

final toggleLikePostProvider = Provider<void Function(String postId, bool isLiked)>((Ref ref) {
  final repo = ref.watch(postRepositoryProvider);
  return (postId, isLiked) => repo.toggleLike(postId, isLiked);
});
