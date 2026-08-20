import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum AdminActionLogStatus { loading, content, empty, error }

class AdminActionLogState {
  const AdminActionLogState({
    required this.status,
    this.entries = const [],
    this.errorMessage,
  });

  const AdminActionLogState.loading()
    : this(status: AdminActionLogStatus.loading);

  final AdminActionLogStatus status;
  final List<AdminAuditLog> entries;
  final String? errorMessage;
}

final adminActionLogControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminActionLogController,
      AdminActionLogState
    >((ref) {
      final controller = AdminActionLogController(
        ref.watch(adminRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class AdminActionLogController extends StateNotifier<AdminActionLogState> {
  AdminActionLogController(this._repository)
    : super(const AdminActionLogState.loading());

  final AdminRepository _repository;

  Future<void> load() async {
    state = const AdminActionLogState.loading();
    try {
      final entries = await _repository.loadAdminActionLogs();
      state = AdminActionLogState(
        status: entries.isEmpty
            ? AdminActionLogStatus.empty
            : AdminActionLogStatus.content,
        entries: List.unmodifiable(entries),
      );
    } on Object {
      state = const AdminActionLogState(
        status: AdminActionLogStatus.error,
        errorMessage:
            'Unable to retrieve the admin action log. Check your connection and try again.',
      );
    }
  }
}
