import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/core/config/supabase_config.dart';

import 'package:makanspot/features/community/models/community_models.dart';

import '../models/fixture_journey_repository.dart';
import '../models/journey_models.dart';
import '../models/journey_repository.dart';
import '../models/supabase_journey_repository.dart';

enum JourneyStatus { loading, content, error }

enum AchievementTab { earned, locked, history }

enum JourneyVisitPeriod { allTime, last30Days, last12Months, yearToDate }

enum JourneyActivityFilter { all, reviews }

class JourneyState {
  const JourneyState({
    required this.status,
    this.data,
    this.visitSearch = '',
    this.visitPeriod = JourneyVisitPeriod.allTime,
    this.activityFilter = JourneyActivityFilter.all,
    this.selectedLocationId,
    this.achievementTab = AchievementTab.earned,
    this.errorMessage,
  });

  const JourneyState.loading() : this(status: JourneyStatus.loading);

  final JourneyStatus status;
  final JourneyData? data;
  final String visitSearch;
  final JourneyVisitPeriod visitPeriod;
  final JourneyActivityFilter activityFilter;
  final String? selectedLocationId;
  final AchievementTab achievementTab;
  final String? errorMessage;

  List<JourneyVisit> get filteredVisits {
    final query = visitSearch.trim().toLowerCase();
    final now = DateTime.now();
    final DateTime? from = switch (visitPeriod) {
      JourneyVisitPeriod.allTime => null,
      JourneyVisitPeriod.last30Days => now.subtract(const Duration(days: 30)),
      JourneyVisitPeriod.last12Months => DateTime(
        now.year - 1,
        now.month,
        now.day,
      ),
      JourneyVisitPeriod.yearToDate => DateTime(now.year, 1, 1),
    };
    return data?.visits
            .where((visit) {
              final matchesQuery =
                  query.isEmpty ||
                  visit.restaurantName.toLowerCase().contains(query) ||
                  visit.cuisine.toLowerCase().contains(query);
              final matchesDate =
                  from == null || !visit.visitDate.isBefore(from);
              final matchesActivity =
                  activityFilter == JourneyActivityFilter.all ||
                  visit.postId != null;
              return matchesQuery && matchesDate && matchesActivity;
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
    JourneyVisitPeriod? visitPeriod,
    JourneyActivityFilter? activityFilter,
    String? selectedLocationId,
    AchievementTab? achievementTab,
    String? errorMessage,
  }) {
    return JourneyState(
      status: status ?? this.status,
      data: data ?? this.data,
      visitSearch: visitSearch ?? this.visitSearch,
      visitPeriod: visitPeriod ?? this.visitPeriod,
      activityFilter: activityFilter ?? this.activityFilter,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
      achievementTab: achievementTab ?? this.achievementTab,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Locations whose coordinates can be placed on the map.
  List<JourneyLocation> get locationsWithCoords {
    return data?.locations
            .where(
              (location) => location.latitude != 0 || location.longitude != 0,
            )
            .toList(growable: false) ??
        const [];
  }

  /// Locations without usable coordinates, shown as a list below the map.
  List<JourneyLocation> get locationsWithoutCoords {
    return data?.locations
            .where(
              (location) => location.latitude == 0 && location.longitude == 0,
            )
            .toList(growable: false) ??
        const [];
  }

  /// Whether at least one visit can be drawn on the interactive map.
  bool get mapAvailable => locationsWithCoords.isNotEmpty;
}

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseJourneyRepository(Supabase.instance.client);
  }
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

  List<JourneyAchievementProgress> calculateAchievements([
    JourneyData? journeyData,
  ]) {
    final data = journeyData ?? state.data;
    return data?.achievementProgress ?? const [];
  }

  int calculateCommunityScore({
    int? dailyLogins,
    int? reviewsSubmitted,
    int? likesReceived,
  }) {
    final data = state.data;
    final reviews = reviewsSubmitted ?? data?.reviewCount ?? 0;
    final likes = likesReceived ?? data?.totalLikes ?? 0;
    final logins = dailyLogins ?? _dailyLoginCount(data?.scoreHistory ?? []);
    return logins + (reviews * 2) + likes;
  }

  String assignProfileTitle({int? communityScore}) {
    final score = communityScore ?? state.data?.user.communityScore ?? 0;
    final hasMasterReviewer = calculateAchievements().any(
      (item) => item.achievement.name == 'Review Regular' && item.earned,
    );
    if (score >= 500) return 'Food Master';
    if (hasMasterReviewer) return 'Master Reviewer';
    if (score >= 100) return 'Explorer';
    return 'Food Explorer';
  }

  int _dailyLoginCount(List<JourneyScoreActivity> history) {
    return history
        .where(
          (activity) => activity.description.toLowerCase().contains('login'),
        )
        .map(
          (activity) => DateTime(
            activity.date.year,
            activity.date.month,
            activity.date.day,
          ),
        )
        .toSet()
        .length;
  }

  void updateVisitSearch(String value) {
    state = state.copyWith(visitSearch: value);
  }

  void updateVisitPeriod(JourneyVisitPeriod period) {
    state = state.copyWith(visitPeriod: period);
  }

  void updateActivityFilter(JourneyActivityFilter filter) {
    state = state.copyWith(activityFilter: filter);
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
    final hasCoords = location.latitude != 0 || location.longitude != 0;
    final query = hasCoords
        ? '${location.latitude},${location.longitude}'
        : location.name;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }
}
