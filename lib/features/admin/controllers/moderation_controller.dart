import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum ModerationStatus { loading, content, error }

enum ReportFilter { all, pending, removed }

enum ReportTab { post, comment }

class ModerationState {
  const ModerationState({
    required this.status,
    this.groups = const [],
    this.filter = ReportFilter.all,
    this.tab = ReportTab.post,
    this.errorMessage,
  });

  const ModerationState.loading({this.tab = ReportTab.post})
    : status = ModerationStatus.loading,
      groups = const [],
      filter = ReportFilter.all,
      errorMessage = null;

  final ModerationStatus status;
  final List<ReportedContentGroup> groups;
  final ReportFilter filter;
  final ReportTab tab;
  final String? errorMessage;

  List<ReportedContentGroup> get filteredPosts =>
      _filteredFor(ReportContentType.post);

  List<ReportedContentGroup> get filteredComments =>
      _filteredFor(ReportContentType.comment);

  List<ReportedContentGroup> _filteredFor(ReportContentType contentType) {
    return groups
        .where((group) {
          if (group.contentType != contentType) return false;

          final matchesFilter = switch (filter) {
            ReportFilter.all => true,
            ReportFilter.pending => group.isPending,
            ReportFilter.removed => group.isRemoved,
          };

          return matchesFilter;
        })
        .toList(growable: false);
  }

  ModerationState copyWith({
    ModerationStatus? status,
    List<ReportedContentGroup>? groups,
    ReportFilter? filter,
    ReportTab? tab,
    String? errorMessage,
  }) {
    return ModerationState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      filter: filter ?? this.filter,
      tab: tab ?? this.tab,
      errorMessage: errorMessage,
    );
  }
}

/// Family keyed by the initial tab so the moderation list can open
/// directly on the Reported Comments tab (via `?tab=comment`) without
/// first rendering the posts tab.
final moderationControllerProvider = StateNotifierProvider.autoDispose
    .family<ModerationController, ModerationState, ReportTab>((ref, tab) {
      final controller = ModerationController(
        ref.watch(adminRepositoryProvider),
        tab,
      );
      controller.load();
      return controller;
    });

class ModerationController extends StateNotifier<ModerationState> {
  ModerationController(
    this._repository, [
    ReportTab initialTab = ReportTab.post,
  ]) : super(ModerationState.loading(tab: initialTab));

  final AdminRepository _repository;

  Future<void> load() async {
    // Keep the current content visible while refreshing so a pull-to-
    // refresh or tab switch does not flash a loading skeleton.
    if (state.status != ModerationStatus.content) {
      state = ModerationState.loading(tab: state.tab);
    }
    try {
      final groups = await _repository.loadReportedContentGroups();
      state = ModerationState(
        status: ModerationStatus.content,
        groups: List.unmodifiable(groups),
        filter: state.filter,
        tab: state.tab,
      );
    } on Object {
      state = state.copyWith(
        status: ModerationStatus.error,
        errorMessage: 'We could not load reports right now.',
      );
    }
  }

  void selectFilter(ReportFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Switches the active tab and reloads the reports so newly reported
  /// content appears without leaving the page.
  Future<void> selectTab(ReportTab tab) async {
    if (tab == state.tab) {
      return;
    }
    state = state.copyWith(tab: tab);
    await load();
  }
}
