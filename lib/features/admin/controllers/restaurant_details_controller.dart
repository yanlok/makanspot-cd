import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum RestaurantDetailsStatus { loading, content, notFound, error }

class AdminSaveResult {
  const AdminSaveResult({this.error, this.createdId});

  final String? error;

  /// Set when a new restaurant was created.
  final String? createdId;
}

class RestaurantDetailsState {
  const RestaurantDetailsState({
    required this.status,
    this.restaurant,
    this.isSaving = false,
    this.errorMessage,
  });

  const RestaurantDetailsState.loading()
    : this(status: RestaurantDetailsStatus.loading);

  final RestaurantDetailsStatus status;
  final AdminRestaurant? restaurant;
  final bool isSaving;
  final String? errorMessage;

  RestaurantDetailsState copyWith({
    RestaurantDetailsStatus? status,
    AdminRestaurant? restaurant,
    bool? isSaving,
    String? errorMessage,
  }) {
    return RestaurantDetailsState(
      status: status ?? this.status,
      restaurant: restaurant ?? this.restaurant,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

final restaurantDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<RestaurantDetailsController, RestaurantDetailsState, String>((
      ref,
      id,
    ) {
      final controller = RestaurantDetailsController(
        ref.watch(adminRepositoryProvider),
        id,
      );
      controller.load();
      return controller;
    });

class RestaurantDetailsController
    extends StateNotifier<RestaurantDetailsState> {
  RestaurantDetailsController(this._repository, this._restaurantId)
    : super(const RestaurantDetailsState.loading());

  final AdminRepository _repository;
  final String _restaurantId;

  bool get isCreate => _restaurantId == 'new';

  Future<void> load() async {
    if (isCreate) {
      state = const RestaurantDetailsState(
        status: RestaurantDetailsStatus.content,
      );
      return;
    }
    state = const RestaurantDetailsState.loading();
    try {
      final restaurant = await _repository.loadRestaurant(_restaurantId);
      if (restaurant == null) {
        state = const RestaurantDetailsState(
          status: RestaurantDetailsStatus.notFound,
        );
        return;
      }
      state = RestaurantDetailsState(
        status: RestaurantDetailsStatus.content,
        restaurant: restaurant,
      );
    } on Object {
      state = const RestaurantDetailsState(
        status: RestaurantDetailsStatus.error,
        errorMessage: 'We could not load this restaurant right now.',
      );
    }
  }

  Future<AdminSaveResult> save(AdminRestaurantDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      return const AdminSaveResult(error: 'Restaurant name is required');
    }
    state = state.copyWith(isSaving: true);
    try {
      if (isCreate) {
        final created = await _repository.createRestaurant(
          _draftWithName(draft, name),
        );
        state = state.copyWith(
          isSaving: false,
          restaurant: created,
          status: RestaurantDetailsStatus.content,
        );
        return AdminSaveResult(createdId: created.id);
      }
      final updated = await _repository.updateRestaurant(
        _restaurantId,
        _draftWithName(draft, name),
      );
      state = state.copyWith(isSaving: false, restaurant: updated);
      return const AdminSaveResult();
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save restaurant.',
      );
      return AdminSaveResult(error: state.errorMessage);
    }
  }

  AdminRestaurantDraft _draftWithName(AdminRestaurantDraft draft, String name) {
    return AdminRestaurantDraft(
      name: name,
      cuisine: draft.cuisine,
      address: draft.address,
      operatingHours: draft.operatingHours,
      contact: draft.contact,
      budget: draft.budget,
      description: draft.description,
      imageUrl: draft.imageUrl,
      sourcePlatform: draft.sourcePlatform,
      isVerified: draft.isVerified,
      rating: draft.rating,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }

  /// Returns a user-facing failure message, or null when removal succeeded.
  Future<String?> remove() async {
    if (isCreate) {
      return null;
    }
    try {
      await _repository.deleteRestaurant(_restaurantId);
      return null;
    } on Object {
      return 'Could not remove restaurant.';
    }
  }

  /// Fixture upload: simulates the cover image upload and returns the new
  /// image URL, or null when the simulated upload failed.
  Future<String?> uploadImage() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'https://images.unsplash.com/photo-1552566626-52f8b828add9'
        '?auto=format&fit=crop&w=900&q=80';
  }
}
