import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum RestaurantDetailsStatus { loading, content, notFound, error }

class AdminSaveResult {
  const AdminSaveResult({this.error, this.warning, this.createdId});

  final String? error;

  /// Non-fatal follow-up problem after a restaurant was persisted.
  final String? warning;

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

  Future<AdminSaveResult> save(
    AdminRestaurantDraft draft, {
    String rawRating = '',
    String rawLatitude = '',
    String rawLongitude = '',
  }) async {
    final name = draft.name.trim();
    final validationError = _validateDraft(
      draft,
      rawRating: rawRating,
      rawLatitude: rawLatitude,
      rawLongitude: rawLongitude,
    );
    if (validationError != null) {
      return AdminSaveResult(error: validationError);
    }

    final existing = state.restaurant;
    try {
      final hasDuplicate = await _repository.restaurantNameExists(
        name,
        excludeRestaurantId: isCreate ? null : existing?.id,
      );
      if (hasDuplicate) {
        return const AdminSaveResult(
          error: 'A restaurant with this name already exists.',
        );
      }
    } on Object {
      return const AdminSaveResult(
        error: 'Could not check for duplicate restaurant records.',
      );
    }

    final normalizedDraft = _draftWithName(draft, name);
    final draftChanges = existing == null
        ? const <String, Map<String, Object?>>{}
        : _fieldChanges(existing, normalizedDraft);
    if (!isCreate && draftChanges.isEmpty) {
      return const AdminSaveResult(error: 'No changes to save.');
    }

    state = state.copyWith(isSaving: true);
    try {
      if (isCreate) {
        final created = await _repository.createRestaurant(normalizedDraft);
        state = state.copyWith(
          isSaving: false,
          restaurant: created,
          status: RestaurantDetailsStatus.content,
        );
        return AdminSaveResult(createdId: created.id);
      }
      final updated = await _repository.updateRestaurant(
        _restaurantId,
        normalizedDraft,
        changedFields: draftChanges.keys.toSet(),
      );
      if (updated == null) {
        state = state.copyWith(isSaving: false);
        return const AdminSaveResult(error: 'Restaurant could not be found.');
      }
      // Record the fields returned by the database, rather than merely the
      // submitted draft. This keeps the audit log truthful on deployments
      // whose restaurant schema has fewer optional fields.
      String? warning;
      if (!_repository.restaurantUpdatesAreAutomaticallyAudited) {
        try {
          await _recordRestaurantUpdate(
            updated,
            existing == null
                ? const <String, Map<String, Object?>>{}
                : _restaurantChanges(existing, updated),
          );
        } on Object {
          // Fixture and custom repositories can use an application-level
          // audit write. Supabase performs this atomically in a DB trigger.
          warning =
              'Restaurant saved, but the admin action log could not be updated.';
        }
      }
      state = state.copyWith(isSaving: false, restaurant: updated);
      return AdminSaveResult(warning: warning);
    } on RestaurantUpdateNoRowsException {
      const message =
          'Restaurant could not be updated. It may no longer exist or your '
          'admin account may not have update permission.';
      state = state.copyWith(isSaving: false, errorMessage: message);
      return const AdminSaveResult(error: message);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('Restaurant update failed (${error.code}): ${error.message}');
      debugPrintStack(
        label: 'Restaurant update stack trace',
        stackTrace: stackTrace,
      );
      final message = _restaurantSaveError(error);
      state = state.copyWith(isSaving: false, errorMessage: message);
      return AdminSaveResult(error: message);
    } on Object catch (error, stackTrace) {
      debugPrint('Restaurant update failed: $error');
      debugPrintStack(
        label: 'Restaurant update stack trace',
        stackTrace: stackTrace,
      );
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
      ownerName: draft.ownerName,
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

  String? _validateDraft(
    AdminRestaurantDraft draft, {
    required String rawRating,
    required String rawLatitude,
    required String rawLongitude,
  }) {
    if (draft.name.trim().isEmpty) return 'Restaurant name is required.';
    if (draft.name.trim().length > 120) {
      return 'Restaurant name must be 120 characters or fewer.';
    }
    if (draft.cuisine.trim().isEmpty) return 'Select a cuisine.';
    if (draft.address.trim().isEmpty) return 'Restaurant address is required.';

    final contact = draft.contact.trim();
    if (contact.isNotEmpty && !_phonePattern.hasMatch(contact)) {
      return 'Enter a valid contact number.';
    }

    final rating = rawRating.trim();
    if (rating.isNotEmpty &&
        (draft.rating == null || draft.rating! < 0 || draft.rating! > 5)) {
      return 'Rating must be a number between 0 and 5.';
    }

    final latitude = rawLatitude.trim();
    final longitude = rawLongitude.trim();
    if (latitude.isEmpty != longitude.isEmpty) {
      return 'Enter both latitude and longitude, or leave both blank.';
    }
    if (latitude.isNotEmpty &&
        (draft.latitude == null ||
            draft.longitude == null ||
            draft.latitude! < -90 ||
            draft.latitude! > 90 ||
            draft.longitude! < -180 ||
            draft.longitude! > 180)) {
      return 'Enter valid latitude and longitude coordinates.';
    }
    return null;
  }

  Map<String, Map<String, Object?>> _fieldChanges(
    AdminRestaurant current,
    AdminRestaurantDraft draft,
  ) {
    final changes = <String, Map<String, Object?>>{};

    void add(String field, Object? from, Object? to) {
      if ('$from' != '$to') changes[field] = {'from': from, 'to': to};
    }

    add('name', current.name, draft.name.trim());
    add('cuisine', current.cuisine, draft.cuisine.trim());
    add('address', current.address, draft.address.trim());
    add('operating_hours', current.operatingHours, draft.operatingHours.trim());
    add('contact', current.contact, draft.contact.trim());
    add('owner_name', current.ownerName, draft.ownerName.trim());
    add('rating', current.rating ?? '', draft.rating ?? '');
    add('budget', current.budget, draft.budget);
    add('description', current.description, draft.description.trim());
    add('image_url', current.imageUrl, draft.imageUrl.trim());
    add('source_platform', current.sourcePlatform, draft.sourcePlatform.trim());
    add(
      'verification_status',
      current.verificationStatus,
      draft.isVerified ? 'Verified' : 'Pending',
    );
    add('latitude', current.latitude ?? '', draft.latitude ?? '');
    add('longitude', current.longitude ?? '', draft.longitude ?? '');
    return changes;
  }

  Map<String, Map<String, Object?>> _restaurantChanges(
    AdminRestaurant from,
    AdminRestaurant to,
  ) {
    final changes = <String, Map<String, Object?>>{};

    void add(String field, Object? previous, Object? next) {
      if ('$previous' != '$next') {
        changes[field] = {'from': previous, 'to': next};
      }
    }

    add('name', from.name, to.name);
    add('cuisine', from.cuisine, to.cuisine);
    add('address', from.address, to.address);
    add('operating_hours', from.operatingHours, to.operatingHours);
    add('contact', from.contact, to.contact);
    add('owner_name', from.ownerName, to.ownerName);
    add('rating', from.rating ?? '', to.rating ?? '');
    add('budget', from.budget, to.budget);
    add('description', from.description, to.description);
    add('image_url', from.imageUrl, to.imageUrl);
    add('source_platform', from.sourcePlatform, to.sourcePlatform);
    add('verification_status', from.verificationStatus, to.verificationStatus);
    add('latitude', from.latitude ?? '', to.latitude ?? '');
    add('longitude', from.longitude ?? '', to.longitude ?? '');
    return changes;
  }

  Future<void> _recordRestaurantUpdate(
    AdminRestaurant restaurant,
    Map<String, Map<String, Object?>> changes,
  ) async {
    await _repository.logAdminAction(
      adminUserId: _fallbackAdminId,
      adminUsername: _fallbackAdminUsername,
      action: 'update_restaurant',
      targetUsername: restaurant.name,
      fieldChanges: changes,
    );
  }

  static const _fallbackAdminId = '00000000-0000-0000-0000-000000000000';
  static const _fallbackAdminUsername = 'admin@makanspot.my';
  static final _phonePattern = RegExp(r'^[+()0-9.\-\s]{7,25}$');

  String _restaurantSaveError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (error.code == '23505' || message.contains('duplicate key')) {
      return 'A restaurant with this name already exists.';
    }
    if (error.code == '42501' ||
        message.contains('permission denied') ||
        message.contains('row-level security')) {
      return 'Restaurant updates are not enabled for this admin account. '
          'Apply the admin restaurant UPDATE policy and try again.';
    }
    return 'Could not save restaurant. Please try again.';
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
