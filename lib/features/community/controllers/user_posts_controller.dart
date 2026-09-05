import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../models/community_repository.dart';
import 'community_controller.dart';

enum UserPostsStatus { loading, content, error }

class UserPostsState {
  const UserPostsState({
    required this.status,
    this.posts = const [],
    this.errorMessage,
  });

  const UserPostsState.loading() : this(status: UserPostsStatus.loading);

  final UserPostsStatus status;
  final List<CommunityPost> posts;
  final String? errorMessage;

  UserPostsState copyWith({
    UserPostsStatus? status,
    List<CommunityPost>? posts,
    String? errorMessage,
  }) {
    return UserPostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final userPostsControllerProvider = StateNotifierProvider.autoDispose
    .family<UserPostsController, UserPostsState, String>((ref, userId) {
      final controller = UserPostsController(
        ref.watch(communityRepositoryProvider),
        userId,
      );
      controller.load();
      return controller;
    });

class UserPostsController extends StateNotifier<UserPostsState> {
  UserPostsController(this._repository, this.userId)
    : super(const UserPostsState.loading());

  final CommunityRepository _repository;
  final String userId;

  Future<void> load() async {
    if (!mounted) return;
    state = const UserPostsState.loading();
    try {
      final posts = await _repository.loadUserPosts(userId);
      if (!mounted) return;
      state = UserPostsState(status: UserPostsStatus.content, posts: posts);
    } on Object {
      if (!mounted) return;
      state = const UserPostsState(
        status: UserPostsStatus.error,
        errorMessage: 'We could not load this member’s posts right now.',
      );
    }
  }

  Future<void> toggleLike(String id) async {
    final updated = await _repository.toggleLike(id);
    if (updated == null || !mounted) return;
    state = state.copyWith(
      posts: List.unmodifiable(
        state.posts.map((post) => post.id == id ? updated : post),
      ),
    );
  }

  Future<void> toggleSave(String id) async {
    final updated = await _repository.toggleSave(id);
    if (updated == null || !mounted) return;
    state = state.copyWith(
      posts: List.unmodifiable(
        state.posts.map((post) => post.id == id ? updated : post),
      ),
    );
  }
}
