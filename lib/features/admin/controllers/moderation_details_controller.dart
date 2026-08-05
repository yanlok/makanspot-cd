import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum ModerationDetailsStatus { loading, content, notFound, error }

class ModerationDetailsState {
  const ModerationDetailsState({
    required this.status,
    this.group,
    this.content,
    this.isActing = false,
    this.errorMessage,
  });

  const ModerationDetailsState.loading()
    : this(status: ModerationDetailsStatus.loading);

  final ModerationDetailsStatus status;
  final ReportedContentGroup? group;
  final ReportedContent? content;
  final bool isActing;
  final String? errorMessage;

  ModerationDetailsState copyWith({
    ModerationDetailsStatus? status,
    ReportedContentGroup? group,
    ReportedContent? content,
    bool? isActing,
    String? errorMessage,
  }) {
    return ModerationDetailsState(
      status: status ?? this.status,
      group: group ?? this.group,
      content: content ?? this.content,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
    );
  }
}

final moderationDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<ModerationDetailsController, ModerationDetailsState, String>((
      ref,
      contentId,
    ) {
      final controller = ModerationDetailsController(
        ref.watch(adminRepositoryProvider),
        contentId,
      );
      controller.load();
      return controller;
    });

class ModerationDetailsController
    extends StateNotifier<ModerationDetailsState> {
  ModerationDetailsController(this._repository, this._contentId)
    : super(const ModerationDetailsState.loading());

  final AdminRepository _repository;
  final String _contentId;

  Future<void> load() async {
    state = const ModerationDetailsState.loading();
    try {
      final group = await _repository.loadReportedContentGroup(_contentId);
      if (group == null) {
        state = const ModerationDetailsState(
          status: ModerationDetailsStatus.notFound,
        );
        return;
      }
      final content = await _repository.loadReportedContent(group);
      state = ModerationDetailsState(
        status: ModerationDetailsStatus.content,
        group: group,
        content: content,
      );
    } on Object {
      state = const ModerationDetailsState(
        status: ModerationDetailsStatus.error,
        errorMessage: 'We could not load this report right now.',
      );
    }
  }

  /// Hides the content from public view. Returns a user-facing failure
  /// message, or null when the removal succeeded.
  Future<String?> removeContent() async {
    state = state.copyWith(isActing: true);
    try {
      await _repository.removeContent(_contentId);
      state = state.copyWith(
        isActing: false,
        group: state.group?.copyWith(isRemoved: true),
      );
      return null;
    } on Object {
      state = state.copyWith(
        isActing: false,
        errorMessage: 'Could not remove content.',
      );
      return state.errorMessage;
    }
  }

  /// Deletes all reports for this content (content stays visible).
  Future<String?> dismiss() async {
    state = state.copyWith(isActing: true);
    try {
      await _repository.dismissReports(_contentId);
      state = state.copyWith(
        isActing: false,
        group: state.group?.copyWith(reports: const []),
      );
      return null;
    } on Object {
      state = state.copyWith(
        isActing: false,
        errorMessage: 'Could not dismiss reports.',
      );
      return state.errorMessage;
    }
  }
}
