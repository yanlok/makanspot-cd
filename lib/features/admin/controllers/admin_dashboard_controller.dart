import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum AdminDashboardStatus { loading, content, error }

class AdminDashboardState {
  const AdminDashboardState({required this.status, this.data});

  const AdminDashboardState.loading()
    : this(status: AdminDashboardStatus.loading);

  final AdminDashboardStatus status;
  final AdminDashboardData? data;
}

final adminDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminDashboardController,
      AdminDashboardState
    >((ref) {
      final controller = AdminDashboardController(
        ref.watch(adminRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  AdminDashboardController(this._repository)
    : super(const AdminDashboardState.loading());

  final AdminRepository _repository;

  Future<void> load() async {
    state = const AdminDashboardState.loading();
    try {
      state = AdminDashboardState(
        status: AdminDashboardStatus.content,
        data: await _repository.loadDashboard(),
      );
    } on Object {
      state = const AdminDashboardState(status: AdminDashboardStatus.error);
    }
  }
}
