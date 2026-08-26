import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../models/community_repository.dart';
import 'community_controller.dart';

enum MyPostsStatus { loading, content, error }

class MyPostsState {
  const MyPostsState({
    required this.status,
    this.posts = const [],
    this.showArchived = false,
    this.errorMessage,
  });

  const MyPostsState.loading() : this(status: MyPostsStatus.loading);

  final MyPostsStatus status;
  final List<CommunityPost> posts;
  final bool showArchived;
  final String? errorMessage;

  List<CommunityPost> get visiblePosts => posts
      .where((post) => (post.status == 'archived') == showArchived)
      .toList(growable: false);

  int get activeCount =>
      posts.where((post) => post.status != 'archived').length;
  int get archivedCount =>
      posts.where((post) => post.status == 'archived').length;

  MyPostsState copyWith({
    MyPostsStatus? status,
    List<CommunityPost>? posts,
    bool? showArchived,
    String? errorMessage,
  }) {
    return MyPostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      showArchived: showArchived ?? this.showArchived,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final myPostsControllerProvider =
    StateNotifierProvider.autoDispose<MyPostsController, MyPostsState>((ref) {
      final controller = MyPostsController(
        ref.watch(communityRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class MyPostsController extends StateNotifier<MyPostsState> {
  MyPostsController(this._repository) : super(const MyPostsState.loading());

  final CommunityRepository _repository;

  Future<void> load() async {
    try {
      state = MyPostsState(
        status: MyPostsStatus.content,
        posts: await _repository.loadMyPosts(),
      );
    } on Object {
      state = const MyPostsState(
        status: MyPostsStatus.error,
        errorMessage: 'We could not load your posts right now.',
      );
    }
  }

  void selectArchived(bool value) {
    state = state.copyWith(showArchived: value);
  }

  Future<void> archive(String id) async {
    await _repository.archivePost(id);
    await load();
  }

  Future<void> unarchive(String id) async {
    await _repository.unarchivePost(id);
    await load();
  }

  Future<void> toggleSave(String id) async {
    await _repository.toggleSave(id);
    await load();
  }
}
