import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/post_repository.dart';
import '../../../shared/models/post_model.dart';

final postRepositoryProvider = Provider((Ref ref) {
  return PostRepository(Supabase.instance.client);
});

final communityFeedProvider = FutureProvider<List<PostModel>>((Ref ref) async {
  return ref.watch(postRepositoryProvider).getFeed();
});
