import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../../models/discover_restaurant.dart';

class DiscoverRestaurantCard extends StatelessWidget {
  const DiscoverRestaurantCard({
    required this.restaurant,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onOpen,
    this.isSelected = false,
    super.key,
  });

  final DiscoverRestaurant restaurant;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onOpen;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.secondary,
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('discover-restaurant-${restaurant.id}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MakanNetworkImage(
                    url: restaurant.imageUrl,
                    semanticLabel: restaurant.name,
                    fallbackKey: Key('discover-image-${restaurant.id}'),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 48,
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: restaurant.labels
                          .take(2)
                          .map((label) => _OverlayBadge(label: label))
                          .toList(),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 10,
                    child: Semantics(
                      button: true,
                      label: isBookmarked
                          ? 'Remove bookmark ${restaurant.name}'
                          : 'Bookmark ${restaurant.name}',
                      child: Material(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: InkWell(
                          key: Key('discover-bookmark-${restaurant.id}'),
                          customBorder: const CircleBorder(),
                          onTap: onBookmark,
                          child: SizedBox.square(
                            dimension: 36,
                            child: Icon(
                              LucideIcons.bookmark,
                              size: 17,
                              color: isBookmarked
                                  ? AppColors.primary
                                  : AppColors.secondaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    restaurant.cuisine,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _Metadata(restaurant: restaurant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.restaurant});

  final DiscoverRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (restaurant.rating case final rating?) ...[
            const Icon(LucideIcons.star, size: 14, color: AppColors.accent),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1)),
            const SizedBox(width: 8),
          ],
          if (restaurant.distanceKm case final distance?) ...[
            const Icon(
              LucideIcons.mapPin,
              size: 14,
              color: AppColors.secondaryForeground,
            ),
            const SizedBox(width: 2),
            Text('${distance.toStringAsFixed(distance % 1 == 0 ? 0 : 1)}km'),
            const SizedBox(width: 10),
          ],
          Text(
            restaurant.budget,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD93B2921),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.surface,
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
