import 'package:flutter_test/flutter_test.dart';

import 'package:makanspot/features/admin/controllers/restaurant_details_controller.dart';
import 'package:makanspot/features/admin/models/admin_models.dart';
import 'package:makanspot/features/admin/models/fixture_admin_repository.dart';

void main() {
  group('RestaurantDetailsController', () {
    test('persists edited details and appends an admin action log', () async {
      final repository = FixtureAdminRepository();
      final original = (await repository.loadRestaurants()).first;
      final updatedRating = original.rating == 4.7 ? 4.2 : 4.7;
      final controller = RestaurantDetailsController(repository, original.id);
      await controller.load();

      final result = await controller.save(
        _draftFrom(
          original,
          name: '${original.name} Updated',
          ownerName: 'Updated Owner',
          rating: updatedRating,
          description: 'Updated restaurant description',
          sourcePlatform: 'Admin Console',
        ),
        rawRating: '$updatedRating',
        rawLatitude: '${original.latitude ?? 3.139}',
        rawLongitude: '${original.longitude ?? 101.6869}',
      );

      expect(result.error, isNull);
      expect(result.warning, isNull);

      final saved = await repository.loadRestaurant(original.id);
      expect(saved, isNotNull);
      expect(saved!.name, '${original.name} Updated');
      expect(saved.ownerName, 'Updated Owner');
      expect(saved.rating, updatedRating);
      expect(saved.description, 'Updated restaurant description');
      expect(saved.sourcePlatform, 'Admin Console');

      final logs = await repository.loadAdminActionLogs();
      expect(logs.first.action, 'update_restaurant');
      expect(logs.first.targetUsername, saved.name);
      expect(logs.first.fieldChanges, contains('owner_name'));
      expect(logs.first.fieldChanges, contains('rating'));
      expect(logs.first.fieldChanges, contains('description'));
    });

    test('rejects a duplicate normalized restaurant name', () async {
      final repository = FixtureAdminRepository();
      final restaurants = await repository.loadRestaurants();
      final original = restaurants.first;
      final duplicate = restaurants[1];
      final controller = RestaurantDetailsController(repository, original.id);
      await controller.load();

      final result = await controller.save(
        _draftFrom(original, name: '  ${duplicate.name.toUpperCase()}  '),
        rawRating: '${original.rating ?? ''}',
        rawLatitude: '${original.latitude ?? 3.139}',
        rawLongitude: '${original.longitude ?? 101.6869}',
      );

      expect(result.error, 'A restaurant with this name already exists.');
    });

    test('validates numeric fields before issuing a save', () async {
      final repository = FixtureAdminRepository();
      final original = (await repository.loadRestaurants()).first;
      final controller = RestaurantDetailsController(repository, original.id);
      await controller.load();

      final result = await controller.save(
        _draftFrom(original, clearRating: true),
        rawRating: 'not-a-rating',
        rawLatitude: '${original.latitude ?? 3.139}',
        rawLongitude: '${original.longitude ?? 101.6869}',
      );

      expect(result.error, 'Rating must be a number between 0 and 5.');
    });
  });
}

AdminRestaurantDraft _draftFrom(
  AdminRestaurant restaurant, {
  String? name,
  String? ownerName,
  double? rating,
  bool clearRating = false,
  String? description,
  String? sourcePlatform,
}) {
  return AdminRestaurantDraft(
    name: name ?? restaurant.name,
    cuisine: restaurant.cuisine,
    address: restaurant.address,
    operatingHours: restaurant.operatingHours,
    contact: restaurant.contact,
    ownerName: ownerName ?? restaurant.ownerName,
    budget: restaurant.budget,
    description: description ?? restaurant.description,
    imageUrl: restaurant.imageUrl,
    sourcePlatform: sourcePlatform ?? restaurant.sourcePlatform,
    isVerified: restaurant.isVerified,
    rating: clearRating ? null : rating ?? restaurant.rating,
    latitude: restaurant.latitude ?? 3.139,
    longitude: restaurant.longitude ?? 101.6869,
  );
}
