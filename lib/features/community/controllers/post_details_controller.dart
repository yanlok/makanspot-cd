import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../models/community_repository.dart';
import 'community_controller.dart';

enum PostDetailsStatus { loading, content, notFound, error }

class PostDetailsState {
  const PostDetailsState({
    required this.status,
    this.post,
    this.comments = const [],
    this.errorMessage,
    this.isLikePending = false,
  });

  const PostDetailsState.loading() : this(status: PostDetailsStatus.loading);

  final PostDetailsStatus status;
  final CommunityPost? post;
  final List<CommunityComment> comments;
  final String? errorMessage;
  final bool isLikePending;

  PostDetailsState copyWith({
    PostDetailsStatus? status,
    CommunityPost? post,
    List<CommunityComment>? comments,
    String? errorMessage,
    bool? isLikePending,
  }) {
    return PostDetailsState(
      status: status ?? this.status,
      post: post ?? this.post,
      comments: comments ?? this.comments,
      errorMessage: errorMessage ?? this.errorMessage,
      isLikePending: isLikePending ?? this.isLikePending,
    );
  }
}

final postDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<PostDetailsController, PostDetailsState, String>((ref, id) {
      final controller = PostDetailsController(
        ref.watch(communityRepositoryProvider),
        id,
      );
      controller.load();
      return controller;
    });

class PostDetailsController extends StateNotifier<PostDetailsState> {
  PostDetailsController(this._repository, this.postId)
    : super(const PostDetailsState.loading());

  final CommunityRepository _repository;
  final String postId;

  Future<void> load() async {
    state = const PostDetailsState.loading();
    try {
      final details = await _repository.loadPost(postId);
      if (details == null) {
        state = const PostDetailsState(status: PostDetailsStatus.notFound);
        return;
      }
      state = PostDetailsState(
        status: PostDetailsStatus.content,
        post: details.post,
        comments: details.comments,
      );
    } on Object {
      state = const PostDetailsState(
        status: PostDetailsStatus.error,
        errorMessage: 'We could not load this post right now.',
      );
    }
  }

  Future<void> toggleLike() async {
    if (state.isLikePending) return;
    state = state.copyWith(isLikePending: true);
    try {
      final updated = await _repository.toggleLike(postId);
      if (updated != null) {
        state = state.copyWith(post: updated);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isLikePending: false);
      }
    }
  }

  Future<void> addComment(String text, {String? parentCommentId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final comment = await _repository.addComment(
      postId: postId,
      text: trimmed,
      parentCommentId: parentCommentId,
    );
    state = state.copyWith(
      post: state.post?.copyWith(
        commentCount: (state.post?.commentCount ?? state.comments.length) + 1,
      ),
      comments: List.unmodifiable([comment, ...state.comments]),
    );
  }
}
