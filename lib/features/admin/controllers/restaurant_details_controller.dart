import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/admin_repository.dart';

enum RestaurantDetailsStatus { loading, content, notFound, error }

enum RestaurantInformationField {
  name,
  phone,
  website,
  businessHours,
  latitude,
  longitude,
}

class AdminSaveResult {
  const AdminSaveResult({
    this.error,
    this.createdId,
    this.invalidFields = const {},
  });

  final String? error;

  /// Set when a new restaurant was created.
  final String? createdId;

  /// Fields that need the administrator's attention before saving.
  final Set<RestaurantInformationField> invalidFields;
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
        errorMessage: 'Unable to retrieve restaurant information. Please try again.',
      );
    }
  }

  Future<AdminSaveResult> save(AdminRestaurantDraft draft) async {
    final name = draft.name.trim();
    final invalidFields = invalidFieldsFor(draft, name);
    if (invalidFields.isNotEmpty) {
      return AdminSaveResult(
        error: 'Please enter valid information in the required fields.',
        invalidFields: invalidFields,
      );
    }
    if (!isCreate) {
      try {
        if (await _repository.restaurantExists(
          _draftWithName(draft, name),
          _restaurantId,
        )) {
          return const AdminSaveResult(
            error:
                'A similar restaurant record already exists. Please review the information.',
          );
        }
      } on Object catch (error) {
        return AdminSaveResult(
          error: _isDuplicateError(error)
              ? 'A similar restaurant record already exists. Please review the information.'
              : 'Unable to update restaurant information. Please try again.',
        );
      }
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
      if (updated == null) {
        throw StateError('Restaurant update affected no rows.');
      }
      state = state.copyWith(isSaving: false, restaurant: updated);
      return const AdminSaveResult();
    } on Object catch (error) {
      final invalidInformation = _isInvalidInformationError(error);
      state = state.copyWith(
        isSaving: false,
        errorMessage: invalidInformation
            ? 'Please enter valid information in the required fields.'
            : _isDuplicateError(error)
            ? 'A similar restaurant record already exists. Please review the information.'
            : 'Unable to update restaurant information. Please try again.',
      );
      return AdminSaveResult(
        error: state.errorMessage,
        invalidFields: invalidInformation ? invalidFieldsFor(draft, name) : const {},
      );
    }
  }

  AdminRestaurantDraft _draftWithName(AdminRestaurantDraft draft, String name) {
    return AdminRestaurantDraft(
      name: name,
      categories: draft.categories,
      address: draft.address,
      city: draft.city,
      state: draft.state,
      phone: draft.phone,
      website: draft.website,
      instagramUsername: draft.instagramUsername,
      priceRange: draft.priceRange,
      businessHours: draft.businessHours,
      businessHoursText: draft.businessHoursText,
      description: draft.description,
      imageUrl: draft.imageUrl,
      latitude: draft.latitude,
      longitude: draft.longitude,
      latitudeText: draft.latitudeText,
      longitudeText: draft.longitudeText,
    );
  }

  static Set<RestaurantInformationField> invalidFieldsFor(
    AdminRestaurantDraft draft,
    String name,
  ) {
    final invalidFields = <RestaurantInformationField>{};
    if (name.isEmpty) {
      invalidFields.add(RestaurantInformationField.name);
    }

    final phone = draft.phone?.trim() ?? '';
    if (phone.isNotEmpty && !RegExp(r'^01\d-\d{7}$').hasMatch(phone)) {
      invalidFields.add(RestaurantInformationField.phone);
    }

    final businessHours = draft.businessHoursText?.trim() ?? '';
    if (businessHours.isNotEmpty && !_isValidBusinessHours(businessHours)) {
      invalidFields.add(RestaurantInformationField.businessHours);
    }

    final website = draft.website?.trim() ?? '';
    if (website.isNotEmpty) {
      final uri = Uri.tryParse(website);
      if (uri == null ||
          !uri.hasAuthority ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        invalidFields.add(RestaurantInformationField.website);
      }
    }

    if (!_hasValidCoordinate(draft.latitudeText, -90, 90)) {
      invalidFields.add(RestaurantInformationField.latitude);
    }
    if (!_hasValidCoordinate(draft.longitudeText, -180, 180)) {
      invalidFields.add(RestaurantInformationField.longitude);
    }
    return invalidFields;
  }

  static bool _hasValidCoordinate(String? rawValue, double min, double max) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return true;
    final coordinate = double.tryParse(value);
    return coordinate != null && coordinate >= min && coordinate <= max;
  }

  static bool _isValidBusinessHours(String value) {
    final timeRange = RegExp(
      r'^\s*[^:;]+:\s*([01]\d|2[0-3]):[0-5]\d\s*-\s*([01]\d|2[0-3]):[0-5]\d\s*$',
    );
    final entries = value.split(';');
    return entries.isNotEmpty && entries.every(timeRange.hasMatch);
  }

  static bool _isDuplicateError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('23505') ||
        message.contains('duplicate key') ||
        message.contains('similar restaurant record') ||
        message.contains('restaurant with this name already exists');
  }

  static bool _isInvalidInformationError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('22023') ||
        message.contains('invalid restaurant information');
  }

  /// Returns a user-facing failure message, or null when removal succeeded.
  Future<String?> remove({
    required RestaurantRemovalReason reason,
    String? additionalNote,
  }) async {
    if (isCreate) {
      return null;
    }
    try {
      await _repository.deleteRestaurant(
        _restaurantId,
        reason: reason,
        additionalNote: additionalNote,
      );
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
