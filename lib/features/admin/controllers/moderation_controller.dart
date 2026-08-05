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
    this.searchQuery = '',
    this.filter = ReportFilter.all,
    this.tab = ReportTab.post,
    this.errorMessage,
  });

  const ModerationState.loading() : this(status: ModerationStatus.loading);

  final ModerationStatus status;
  final List<ReportedContentGroup> groups;
  final String searchQuery;
  final ReportFilter filter;
  final ReportTab tab;
  final String? errorMessage;

  List<ReportedContentGroup> get filteredPosts =>
      _filteredFor(ReportContentType.post);

  List<ReportedContentGroup> get filteredComments =>
      _filteredFor(ReportContentType.comment);

  List<ReportedContentGroup> _filteredFor(ReportContentType contentType) {
    final query = searchQuery.trim().toLowerCase();
    return groups
        .where((group) {
          if (group.contentType != contentType) return false;

          final matchesSearch =
              query.isEmpty ||
              group.contentPreview.toLowerCase().contains(query) ||
              group.contentOwner.toLowerCase().contains(query) ||
              group.reports.any((r) => r.reason.toLowerCase().contains(query));

          final matchesFilter = switch (filter) {
            ReportFilter.all => true,
            ReportFilter.pending => group.isPending,
            ReportFilter.removed => group.isRemoved,
          };

          return matchesSearch && matchesFilter;
        })
        .toList(growable: false);
  }

  ModerationState copyWith({
    ModerationStatus? status,
    List<ReportedContentGroup>? groups,
    String? searchQuery,
    ReportFilter? filter,
    ReportTab? tab,
    String? errorMessage,
  }) {
    return ModerationState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      tab: tab ?? this.tab,
      errorMessage: errorMessage,
    );
  }
}

final moderationControllerProvider =
    StateNotifierProvider.autoDispose<ModerationController, ModerationState>((
      ref,
    ) {
      final controller = ModerationController(
        ref.watch(adminRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class ModerationController extends StateNotifier<ModerationState> {
  ModerationController(this._repository)
    : super(const ModerationState.loading());

  final AdminRepository _repository;

  Future<void> load() async {
    state = const ModerationState.loading();
    try {
      state = ModerationState(
        status: ModerationStatus.content,
        groups: List.unmodifiable(
          await _repository.loadReportedContentGroups(),
        ),
      );
    } on Object {
      state = const ModerationState(
        status: ModerationStatus.error,
        errorMessage: 'We could not load reports right now.',
      );
    }
  }

  void updateSearch(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void selectFilter(ReportFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void selectTab(ReportTab tab) {
    state = state.copyWith(tab: tab);
  }
}
