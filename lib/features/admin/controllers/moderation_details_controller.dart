import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum ModerationDetailsStatus { loading, content, notFound, error }

class ModerationDetailsState {
  const ModerationDetailsState({
    required this.status,
    this.report,
    this.content,
    this.removalReason = '',
    this.isActing = false,
    this.errorMessage,
  });

  const ModerationDetailsState.loading()
    : this(status: ModerationDetailsStatus.loading);

  final ModerationDetailsStatus status;
  final ModerationReport? report;
  final ReportedContent? content;
  final String removalReason;
  final bool isActing;
  final String? errorMessage;

  ModerationDetailsState copyWith({
    ModerationDetailsStatus? status,
    ModerationReport? report,
    ReportedContent? content,
    String? removalReason,
    bool? isActing,
    String? errorMessage,
  }) {
    return ModerationDetailsState(
      status: status ?? this.status,
      report: report ?? this.report,
      content: content ?? this.content,
      removalReason: removalReason ?? this.removalReason,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
    );
  }
}

final moderationDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<ModerationDetailsController, ModerationDetailsState, String>((
      ref,
      id,
    ) {
      final controller = ModerationDetailsController(
        ref.watch(adminRepositoryProvider),
        id,
      );
      controller.load();
      return controller;
    });

class ModerationDetailsController
    extends StateNotifier<ModerationDetailsState> {
  ModerationDetailsController(this._repository, this._reportId)
    : super(const ModerationDetailsState.loading());

  final AdminRepository _repository;
  final String _reportId;

  Future<void> load() async {
    state = const ModerationDetailsState.loading();
    try {
      final report = await _repository.loadReport(_reportId);
      if (report == null) {
        state = const ModerationDetailsState(
          status: ModerationDetailsStatus.notFound,
        );
        return;
      }
      final content = await _repository.loadReportedContent(report);
      state = ModerationDetailsState(
        status: ModerationDetailsStatus.content,
        report: report,
        content: content,
      );
    } on Object {
      state = const ModerationDetailsState(
        status: ModerationDetailsStatus.error,
        errorMessage: 'We could not load this report right now.',
      );
    }
  }

  void updateRemovalReason(String value) {
    state = state.copyWith(removalReason: value);
  }

  /// Resolves the report by removing the content. Returns a user-facing
  /// failure message, or null when the removal succeeded.
  Future<String?> removeContent() async {
    final report = state.report;
    if (report == null) {
      return null;
    }
    if (state.removalReason.trim().isEmpty) {
      return 'Removal reason required';
    }
    return _resolve(ReportStatus.removed, report);
  }

  Future<String?> dismiss() async {
    final report = state.report;
    if (report == null) {
      return null;
    }
    return _resolve(ReportStatus.dismissed, report);
  }

  Future<String?> _resolve(ReportStatus status, ModerationReport report) async {
    state = state.copyWith(isActing: true);
    try {
      final updated = await _repository.resolveReport(
        id: report.id,
        status: status,
        removalReason: status == ReportStatus.removed
            ? state.removalReason.trim()
            : null,
      );
      state = ModerationDetailsState(
        status: state.status,
        report: updated,
        content:
            status == ReportStatus.removed &&
                report.contentType == ReportContentType.comment
            ? null
            : state.content,
        removalReason: '',
        isActing: false,
      );
      return null;
    } on Object {
      state = state.copyWith(
        isActing: false,
        errorMessage: status == ReportStatus.removed
            ? 'Could not remove content.'
            : 'Could not dismiss report.',
      );
      return state.errorMessage;
    }
  }
}
