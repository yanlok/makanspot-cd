import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/discover_controller.dart';
import '../models/discover_restaurant.dart';

final savedRestaurantsProvider =
    FutureProvider.autoDispose<List<DiscoverRestaurant>>((ref) async {
      final savedIds =
          ref.watch(savedRestaurantIdsProvider).valueOrNull ?? const <String>{};
      final restaurants = await ref
          .watch(discoverRepositoryProvider)
          .loadRestaurants();
      return restaurants
          .where((restaurant) => savedIds.contains(restaurant.id))
          .toList();
    });

class SavedRestaurantScreen extends ConsumerWidget {
  const SavedRestaurantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(savedRestaurantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Restaurants'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.x),
            tooltip: 'Close saved restaurants',
            onPressed: context.pop,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: restaurants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _SavedRestaurantsMessage(
          icon: LucideIcons.wifiOff,
          title: 'Could not load saved restaurants',
          message: 'Please try again in a moment.',
        ),
        data: (items) => items.isEmpty
            ? const _SavedRestaurantsMessage(
                icon: LucideIcons.bookmark,
                title: 'No saved restaurants yet',
                message: 'Restaurants you save in Discover will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _SavedRestaurantTile(restaurant: items[index]),
              ),
      ),
    );
  }
}

class _SavedRestaurantTile extends StatelessWidget {
  const _SavedRestaurantTile({required this.restaurant});

  final DiscoverRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.secondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('saved-restaurant-${restaurant.id}'),
        onTap: () => context.push('/restaurant/${restaurant.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 156,
              child: MakanNetworkImage(
                url: restaurant.imageUrl,
                semanticLabel: restaurant.name,
                fallbackKey: Key('saved-image-${restaurant.id}'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                restaurant.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRestaurantsMessage extends StatelessWidget {
  const _SavedRestaurantsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
