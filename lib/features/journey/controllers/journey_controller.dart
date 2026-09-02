import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:makanspot/features/community/models/community_models.dart';

import '../models/fixture_journey_repository.dart';
import '../models/journey_models.dart';
import '../models/journey_repository.dart';

enum JourneyStatus { loading, content, error }

enum AchievementTab { earned, locked, history }

class JourneyState {
  const JourneyState({
    required this.status,
    this.data,
    this.visitSearch = '',
    this.selectedLocationId,
    this.achievementTab = AchievementTab.earned,
    this.errorMessage,
  });

  const JourneyState.loading() : this(status: JourneyStatus.loading);

  final JourneyStatus status;
  final JourneyData? data;
  final String visitSearch;
  final String? selectedLocationId;
  final AchievementTab achievementTab;
  final String? errorMessage;

  List<JourneyVisit> get filteredVisits {
    final query = visitSearch.trim().toLowerCase();
    return data?.visits
            .where((visit) {
              return query.isEmpty ||
                  visit.restaurantName.toLowerCase().contains(query) ||
                  visit.cuisine.toLowerCase().contains(query);
            })
            .toList(growable: false) ??
        const [];
  }

  JourneyLocation? get selectedLocation {
    return data?.locations
        .where((location) => location.id == selectedLocationId)
        .firstOrNull;
  }

  JourneyState copyWith({
    JourneyStatus? status,
    JourneyData? data,
    String? visitSearch,
    String? selectedLocationId,
    AchievementTab? achievementTab,
    String? errorMessage,
  }) {
    return JourneyState(
      status: status ?? this.status,
      data: data ?? this.data,
      visitSearch: visitSearch ?? this.visitSearch,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
      achievementTab: achievementTab ?? this.achievementTab,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return const FixtureJourneyRepository();
});

final journeyControllerProvider =
    StateNotifierProvider<JourneyController, JourneyState>((ref) {
      final controller = JourneyController(
        ref.watch(journeyRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class JourneyController extends StateNotifier<JourneyState> {
  JourneyController(this._repository) : super(const JourneyState.loading());

  final JourneyRepository _repository;

  Future<void> load() async {
    state = const JourneyState.loading();
    try {
      state = JourneyState(
        status: JourneyStatus.content,
        data: await _repository.loadJourney(),
      );
    } on Object {
      state = const JourneyState(
        status: JourneyStatus.error,
        errorMessage: 'We could not load your journey right now.',
      );
    }
  }

  void updateVisitSearch(String value) {
    state = state.copyWith(visitSearch: value);
  }

  void selectLocation(String id) {
    state = state.copyWith(selectedLocationId: id);
  }

  void selectAchievementTab(AchievementTab tab) {
    state = state.copyWith(achievementTab: tab);
  }

  /// Adds the journey activity created by publishing a new review.
  void recordReview(CommunityPost post, {required String cuisine}) {
    final data = state.data;
    if (state.status != JourneyStatus.content || data == null) {
      return;
    }
    final isNewVisit = !data.visits.any(
      (visit) => visit.restaurantId == post.restaurantId,
    );
    final visits = isNewVisit
        ? [
            ...data.visits,
            JourneyVisit(
              id: 'visit-${post.id}',
              restaurantId: post.restaurantId,
              restaurantName: post.restaurantName,
              restaurantImage: post.restaurantImage,
              cuisine: cuisine,
              visitDate: post.createdAt,
              postId: post.id,
            ),
          ]
        : data.visits;
    final activity = JourneyScoreActivity(
      description: 'Posted review for ${post.restaurantName}',
      points: isNewVisit ? 15 : 10,
      date: post.createdAt,
      isReview: true,
    );
    state = state.copyWith(
      data: data.copyWith(
        user: data.user.copyWith(
          communityScore: data.user.communityScore + activity.points,
        ),
        visits: visits,
        reviewCount: data.reviewCount + 1,
        scoreHistory: [activity, ...data.scoreHistory],
      ),
    );
  }

  Uri mapsDestination(JourneyLocation location) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${location.latitude},${location.longitude}',
    });
  }
}
