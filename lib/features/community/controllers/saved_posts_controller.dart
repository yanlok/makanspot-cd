import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../models/community_repository.dart';
import 'community_controller.dart';

enum SavedPostsStatus { loading, content, empty, error }

class SavedPostsState {
  const SavedPostsState({
    required this.status,
    this.posts = const [],
    this.errorMessage,
  });

  const SavedPostsState.loading() : this(status: SavedPostsStatus.loading);

  final SavedPostsStatus status;
  final List<CommunityPost> posts;
  final String? errorMessage;

  SavedPostsState copyWith({
    SavedPostsStatus? status,
    List<CommunityPost>? posts,
    String? errorMessage,
  }) {
    return SavedPostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final savedPostsControllerProvider =
    StateNotifierProvider.autoDispose<SavedPostsController, SavedPostsState>((
      ref,
    ) {
      final controller = SavedPostsController(
        ref.watch(communityRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class SavedPostsController extends StateNotifier<SavedPostsState> {
  SavedPostsController(this._repository)
    : super(const SavedPostsState.loading());

  final CommunityRepository _repository;

  Future<void> load() async {
    if (!mounted) return;
    state = const SavedPostsState.loading();
    try {
      final posts = await _repository.loadSavedPosts();
      if (!mounted) return;
      state = SavedPostsState(
        status: posts.isEmpty
            ? SavedPostsStatus.empty
            : SavedPostsStatus.content,
        posts: posts,
      );
    } on Object {
      if (!mounted) return;
      state = const SavedPostsState(
        status: SavedPostsStatus.error,
        errorMessage: 'We could not load your saved posts right now.',
      );
    }
  }

  Future<void> toggleSave(String id) async {
    await _repository.toggleSave(id);
    if (!mounted) return;
    await load();
  }
}
