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

  Future<void> toggleSave() async {
    final updated = await _repository.toggleSave(postId);
    if (updated != null && mounted) state = state.copyWith(post: updated);
  }

  Future<void> reportPost(CommunityReportReason reason, {String? details}) {
    return _repository.reportPost(
      postId: postId,
      reason: reason,
      additionalInfo: details,
    );
  }

  Future<void> reportComment(
    String commentId,
    CommunityReportReason reason, {
    String? details,
  }) {
    return _repository.reportComment(
      commentId: commentId,
      reason: reason,
      additionalInfo: details,
    );
  }

  Future<void> addComment(String text, {String? parentCommentId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (parentCommentId == null && state.post?.isOwn == true) {
      return;
    }
    if (parentCommentId != null &&
        state.comments.any(
          (comment) => comment.id == parentCommentId && comment.isOwn,
        )) {
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

  Future<void> deleteComment(String id) async {
    await _repository.deleteComment(id);
    if (!mounted) return;
    state = state.copyWith(
      post: state.post?.copyWith(
        commentCount: (state.post?.commentCount ?? state.comments.length) - 1,
      ),
      comments: List.unmodifiable(
        state.comments.where((comment) => comment.id != id),
      ),
    );
  }

  Future<void> togglePinComment(CommunityComment comment) async {
    await _repository.togglePinComment(
      id: comment.id,
      pinned: !comment.isPinned,
    );
    if (!mounted) return;
    state = state.copyWith(
      comments: List.unmodifiable(
        state.comments.map((item) {
          if (item.id != comment.id) return item;
          return CommunityComment(
            id: item.id,
            postId: item.postId,
            username: item.username,
            userAvatar: item.userAvatar,
            text: item.text,
            userId: item.userId,
            isOwn: item.isOwn,
            canPin: item.canPin,
            isPinned: !item.isPinned,
            createdAt: item.createdAt,
            parentCommentId: item.parentCommentId,
          );
        }),
      ),
    );
  }
}
