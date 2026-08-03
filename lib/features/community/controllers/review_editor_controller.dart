import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../models/community_repository.dart';
import 'community_controller.dart';

enum ReviewEditorStatus { loading, ready, submitting, success, notFound, error }

class ReviewEditorArguments {
  const ReviewEditorArguments({this.postId, this.restaurantId});

  final String? postId;
  final String? restaurantId;

  @override
  bool operator ==(Object other) {
    return other is ReviewEditorArguments &&
        other.postId == postId &&
        other.restaurantId == restaurantId;
  }

  @override
  int get hashCode => Object.hash(postId, restaurantId);
}

class ReviewEditorState {
  const ReviewEditorState({
    required this.status,
    this.restaurants = const [],
    this.selectedRestaurant,
    this.reviewText = '',
    this.mediaUrls = const [],
    this.savedPostId,
    this.errorMessage,
  });

  const ReviewEditorState.loading() : this(status: ReviewEditorStatus.loading);

  final ReviewEditorStatus status;
  final List<CommunityRestaurant> restaurants;
  final CommunityRestaurant? selectedRestaurant;
  final String reviewText;
  final List<String> mediaUrls;
  final String? savedPostId;
  final String? errorMessage;

  bool get canSubmit =>
      selectedRestaurant != null && reviewText.trim().isNotEmpty;

  ReviewEditorState copyWith({
    ReviewEditorStatus? status,
    List<CommunityRestaurant>? restaurants,
    CommunityRestaurant? selectedRestaurant,
    bool clearRestaurant = false,
    String? reviewText,
    List<String>? mediaUrls,
    String? savedPostId,
    String? errorMessage,
  }) {
    return ReviewEditorState(
      status: status ?? this.status,
      restaurants: restaurants ?? this.restaurants,
      selectedRestaurant: clearRestaurant
          ? null
          : selectedRestaurant ?? this.selectedRestaurant,
      reviewText: reviewText ?? this.reviewText,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      savedPostId: savedPostId ?? this.savedPostId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final reviewEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewEditorController, ReviewEditorState, ReviewEditorArguments>((
      ref,
      arguments,
    ) {
      final controller = ReviewEditorController(
        ref.watch(communityRepositoryProvider),
        arguments,
      );
      controller.load();
      return controller;
    });

class ReviewEditorController extends StateNotifier<ReviewEditorState> {
  ReviewEditorController(this._repository, this.arguments)
    : super(const ReviewEditorState.loading());

  final CommunityRepository _repository;
  final ReviewEditorArguments arguments;

  Future<void> load() async {
    try {
      final restaurants = await _repository.loadRestaurants();
      if (arguments.postId != null) {
        final details = await _repository.loadPost(arguments.postId!);
        if (details == null) {
          state = const ReviewEditorState(status: ReviewEditorStatus.notFound);
          return;
        }
        final selected = restaurants
            .where((item) => item.id == details.post.restaurantId)
            .firstOrNull;
        state = ReviewEditorState(
          status: ReviewEditorStatus.ready,
          restaurants: restaurants,
          selectedRestaurant: selected,
          reviewText: details.post.reviewText,
          mediaUrls: details.post.mediaUrls,
        );
        return;
      }
      final selected = restaurants
          .where((item) => item.id == arguments.restaurantId)
          .firstOrNull;
      state = ReviewEditorState(
        status: ReviewEditorStatus.ready,
        restaurants: restaurants,
        selectedRestaurant: selected,
      );
    } on Object {
      state = const ReviewEditorState(
        status: ReviewEditorStatus.error,
        errorMessage: 'We could not prepare the review form right now.',
      );
    }
  }

  void selectRestaurant(CommunityRestaurant restaurant) {
    state = state.copyWith(selectedRestaurant: restaurant);
  }

  void clearRestaurant() {
    state = state.copyWith(clearRestaurant: true);
  }

  void updateReview(String value) {
    state = state.copyWith(reviewText: value);
  }

  void addFixturePhoto() {
    if (state.mediaUrls.isNotEmpty) {
      return;
    }
    state = state.copyWith(
      mediaUrls: [state.selectedRestaurant?.imageUrl ?? ''],
    );
  }

  void removePhoto(int index) {
    state = state.copyWith(
      mediaUrls: List.unmodifiable([
        for (var i = 0; i < state.mediaUrls.length; i++)
          if (i != index) state.mediaUrls[i],
      ]),
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit || state.status == ReviewEditorStatus.submitting) {
      return;
    }
    state = state.copyWith(status: ReviewEditorStatus.submitting);
    try {
      final id = arguments.postId;
      final CommunityPost? saved;
      if (id == null) {
        saved = await _repository.createPost(
          restaurant: state.selectedRestaurant!,
          reviewText: state.reviewText.trim(),
          mediaUrls: state.mediaUrls,
        );
      } else {
        saved = await _repository.updatePost(
          id: id,
          reviewText: state.reviewText.trim(),
          mediaUrls: state.mediaUrls,
        );
      }
      state = state.copyWith(
        status: ReviewEditorStatus.success,
        savedPostId: saved?.id,
      );
    } on Object {
      state = state.copyWith(
        status: ReviewEditorStatus.error,
        errorMessage: 'We could not save your review right now.',
      );
    }
  }
}
