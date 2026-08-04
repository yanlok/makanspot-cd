import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum ModerationStatus { loading, content, error }

enum ReportStatusFilter { all, pending, removed, dismissed }

enum ReportTab { post, comment }

class ModerationState {
  const ModerationState({
    required this.status,
    this.reports = const [],
    this.searchQuery = '',
    this.statusFilter = ReportStatusFilter.all,
    this.tab = ReportTab.post,
    this.errorMessage,
  });

  const ModerationState.loading() : this(status: ModerationStatus.loading);

  final ModerationStatus status;
  final List<ModerationReport> reports;
  final String searchQuery;
  final ReportStatusFilter statusFilter;
  final ReportTab tab;
  final String? errorMessage;

  List<ModerationReport> get filteredPosts {
    return _filteredFor(ReportContentType.post);
  }

  List<ModerationReport> get filteredComments {
    return _filteredFor(ReportContentType.comment);
  }

  List<ModerationReport> _filteredFor(ReportContentType contentType) {
    final query = searchQuery.trim().toLowerCase();
    return reports
        .where((report) {
          if (report.contentType != contentType) {
            return false;
          }
          final matchesSearch =
              query.isEmpty ||
              report.contentPreview.toLowerCase().contains(query) ||
              report.contentOwner.toLowerCase().contains(query) ||
              report.reason.toLowerCase().contains(query);
          final matchesStatus = switch (statusFilter) {
            ReportStatusFilter.all => true,
            ReportStatusFilter.pending => report.status == ReportStatus.pending,
            ReportStatusFilter.removed => report.status == ReportStatus.removed,
            ReportStatusFilter.dismissed =>
              report.status == ReportStatus.dismissed,
          };
          return matchesSearch && matchesStatus;
        })
        .toList(growable: false);
  }

  ModerationState copyWith({
    ModerationStatus? status,
    List<ModerationReport>? reports,
    String? searchQuery,
    ReportStatusFilter? statusFilter,
    ReportTab? tab,
    String? errorMessage,
  }) {
    return ModerationState(
      status: status ?? this.status,
      reports: reports ?? this.reports,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
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
        reports: List.unmodifiable(await _repository.loadReports()),
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

  void selectStatusFilter(ReportStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void selectTab(ReportTab tab) {
    state = state.copyWith(tab: tab);
  }
}
