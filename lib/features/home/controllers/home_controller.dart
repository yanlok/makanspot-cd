import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:makanspot/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../discover/controllers/discover_controller.dart';
import '../models/fixture_home_repository.dart';
import '../models/home_repository.dart';
import '../models/supabase_home_repository.dart';
import 'home_state.dart';

typedef Now = DateTime Function();

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const FixtureHomeRepository();
  }
  try {
    return SupabaseHomeRepository(Supabase.instance.client);
  } on StateError {
    // Keeps previews and tests usable when main() has not initialized Supabase.
    return const FixtureHomeRepository();
  }
});

final homeControllerProvider =
    StateNotifierProvider.autoDispose<HomeController, HomeState>((ref) {
      final controller = HomeController(ref, ref.watch(homeRepositoryProvider));
      controller.load();
      ref.listen<AsyncValue<Set<String>>>(
        savedRestaurantIdsProvider,
        (previous, next) => next.whenData(controller.syncBookmarks),
      );
      // Cover the case where bookmarks already loaded before this controller
      // subscribed (a newly-created provider's resolution is delivered by the
      // listen above).
      ref.read(savedRestaurantIdsProvider).whenData(controller.syncBookmarks);
      return controller;
    });

class HomeController extends StateNotifier<HomeState> {
  HomeController(Ref ref, HomeRepository repository, {Now? now})
    : _ref = ref,
      _repository = repository,
      _now = now ?? DateTime.now,
      super(HomeState.loading(greeting: _greetingFor((now ?? DateTime.now)())));

  final Ref _ref;
  final HomeRepository _repository;
  final Now _now;

  Future<void> load() async {
    if (!mounted) return;
    state = HomeState.loading(greeting: _greetingFor(_now()));
    try {
      final feed = await _repository.loadHome();
      if (!mounted) return;
      state = HomeState(
        status: feed.isEmpty ? HomeStatus.empty : HomeStatus.content,
        greeting: _greetingFor(_now()),
        feed: feed,
        bookmarkedIds: state.bookmarkedIds,
      );
    } on Object {
      if (!mounted) return;
      state = HomeState(
        status: HomeStatus.error,
        greeting: _greetingFor(_now()),
        bookmarkedIds: state.bookmarkedIds,
        errorMessage: 'We could not load nearby makan spots.',
      );
    }
  }

  Uri? searchDestination(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return null;
    }
    return Uri(path: '/discover', queryParameters: {'q': query});
  }

  Uri filterDestination(String filter) {
    return Uri(path: '/discover', queryParameters: {'filter': filter});
  }

  Future<void> toggleBookmark(String restaurantId) async {
    if (!mounted) return;
    await toggleRestaurantBookmark(_ref, restaurantId);
  }

  void syncBookmarks(Set<String> ids) {
    if (!mounted) return;
    state = state.copyWith(bookmarkedIds: Set.unmodifiable(ids));
  }

  static String _greetingFor(DateTime dateTime) {
    return 'Welcome';
  }
}
