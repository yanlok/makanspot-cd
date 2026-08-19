import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:makanspot/core/config/supabase_config.dart';

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
    StateNotifierProvider.autoDispose<JourneyController, JourneyState>((ref) {
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
