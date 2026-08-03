import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../models/community_repository.dart';
import '../models/fixture_community_repository.dart';

enum CommunityStatus { loading, content, empty, error }

class CommunityState {
  const CommunityState({
    required this.status,
    this.posts = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  const CommunityState.loading() : this(status: CommunityStatus.loading);

  final CommunityStatus status;
  final List<CommunityPost> posts;
  final String searchQuery;
  final String? errorMessage;

  CommunityState copyWith({
    CommunityStatus? status,
    List<CommunityPost>? posts,
    String? searchQuery,
    String? errorMessage,
  }) {
    return CommunityState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return FixtureCommunityRepository();
});

final communityControllerProvider =
    StateNotifierProvider.autoDispose<CommunityController, CommunityState>((
      ref,
    ) {
      final controller = CommunityController(
        ref.watch(communityRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class CommunityController extends StateNotifier<CommunityState> {
  CommunityController(this._repository) : super(const CommunityState.loading());

  final CommunityRepository _repository;
  List<CommunityPost> _allPosts = const [];

  Future<void> load() async {
    state = const CommunityState.loading();
    try {
      _allPosts = await _repository.loadCommunityPosts();
      _filter();
    } on Object {
      state = const CommunityState(
        status: CommunityStatus.error,
        errorMessage: 'We could not load community posts right now.',
      );
    }
  }

  void updateSearch(String value) {
    state = state.copyWith(searchQuery: value);
    _filter();
  }

  Future<void> toggleLike(String id) async {
    final updated = await _repository.toggleLike(id);
    if (updated == null) {
      return;
    }
    _allPosts = _allPosts
        .map((post) => post.id == id ? updated : post)
        .toList(growable: false);
    _filter();
  }

  void _filter() {
    final query = state.searchQuery.trim().toLowerCase();
    final posts = _allPosts
        .where((post) {
          return query.isEmpty ||
              post.restaurantName.toLowerCase().contains(query) ||
              post.reviewText.toLowerCase().contains(query) ||
              post.username.toLowerCase().contains(query);
        })
        .toList(growable: false);
    state = state.copyWith(
      status: posts.isEmpty ? CommunityStatus.empty : CommunityStatus.content,
      posts: List.unmodifiable(posts),
    );
  }
}
