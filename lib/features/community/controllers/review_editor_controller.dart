import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
    this.rating = 0,
    this.media = const [],
    this.savedPostId,
    this.errorMessage,
  });

  const ReviewEditorState.loading() : this(status: ReviewEditorStatus.loading);

  final ReviewEditorStatus status;
  final List<CommunityRestaurant> restaurants;
  final CommunityRestaurant? selectedRestaurant;
  final String reviewText;
  final int rating;
  final List<ReviewMedia> media;
  final String? savedPostId;
  final String? errorMessage;

  bool get canSubmit =>
      selectedRestaurant != null && rating > 0 && reviewText.trim().isNotEmpty;

  ReviewEditorState copyWith({
    ReviewEditorStatus? status,
    List<CommunityRestaurant>? restaurants,
    CommunityRestaurant? selectedRestaurant,
    bool clearRestaurant = false,
    String? reviewText,
    int? rating,
    List<ReviewMedia>? media,
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
      rating: rating ?? this.rating,
      media: media ?? this.media,
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
          rating: details.post.rating,
          media: details.post.mediaUrls
              .map(
                (url) => ReviewMedia(path: url, type: _mediaTypeFromPath(url)),
              )
              .toList(growable: false),
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
    } on Object catch (error) {
      state = ReviewEditorState(
        status: ReviewEditorStatus.error,
        errorMessage: 'Could not load restaurants. ${error.toString()}',
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

  void updateRating(int value) {
    state = state.copyWith(rating: value);
  }

  Future<void> pickImages() async {
    if (state.media.length >= 5) {
      return;
    }
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      limit: 5 - state.media.length,
    );
    if (files.isEmpty) return;
    state = state.copyWith(
      media: [
        ...state.media,
        ...files.map(
          (file) => ReviewMedia(
            path: file.path,
            type: ReviewMediaType.image,
            isLocal: true,
          ),
        ),
      ],
    );
  }

  Future<void> pickVideo() async {
    if (state.media.length >= 5) return;
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) return;
    state = state.copyWith(
      media: [
        ...state.media,
        ReviewMedia(
          path: file.path,
          type: ReviewMediaType.video,
          isLocal: true,
        ),
      ],
    );
  }

  void removeMedia(int index) {
    state = state.copyWith(
      media: List.unmodifiable([
        for (var i = 0; i < state.media.length; i++)
          if (i != index) state.media[i],
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
          rating: state.rating,
          media: state.media,
        );
      } else {
        saved = await _repository.updatePost(
          id: id,
          reviewText: state.reviewText.trim(),
          rating: state.rating,
          media: state.media,
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

ReviewMediaType _mediaTypeFromPath(String path) {
  final clean = path.split('?').first.toLowerCase();
  return clean.endsWith('.mp4') ||
          clean.endsWith('.mov') ||
          clean.endsWith('.m4v') ||
          clean.endsWith('.webm')
      ? ReviewMediaType.video
      : ReviewMediaType.image;
}
