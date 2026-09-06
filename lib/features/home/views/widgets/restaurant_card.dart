import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/home/models/restaurant_summary.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import 'status_badge.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    required this.restaurant,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onOpen,
    super.key,
  });

  final RestaurantSummary restaurant;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 256,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.secondary),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 128,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MakanNetworkImage(
                      url: restaurant.imageUrl,
                      semanticLabel: restaurant.name,
                      fallbackKey: Key(
                        'restaurant-image-fallback-${restaurant.id}',
                      ),
                    ),
                    if (restaurant.labels.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 56,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: restaurant.labels
                              .take(2)
                              .map((label) => StatusBadge(label: label))
                              .toList(),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Semantics(
                        label: isBookmarked
                            ? 'Remove bookmark ${restaurant.name}'
                            : 'Bookmark ${restaurant.name}',
                        button: true,
                        child: Material(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            key: Key('bookmark-${restaurant.id}'),
                            customBorder: const CircleBorder(),
                            onTap: onBookmark,
                            child: SizedBox.square(
                              dimension: 36,
                              child: Icon(
                                isBookmarked
                                    ? LucideIcons.bookmarkCheck
                                    : LucideIcons.bookmark,
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
                padding: const EdgeInsets.all(12),
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
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                    if (restaurant.rating != null ||
                        restaurant.distanceKm != null) ...[
                      const SizedBox(height: 8),
                      _RestaurantMetadata(restaurant: restaurant),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantMetadata extends StatelessWidget {
  const _RestaurantMetadata({required this.restaurant});

  final RestaurantSummary restaurant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (restaurant.rating case final rating?) ...[
          const Icon(LucideIcons.star, size: 14, color: AppColors.accent),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              rating.toStringAsFixed(1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (restaurant.distanceKm case final distance?) ...[
          const Icon(
            LucideIcons.mapPin,
            size: 14,
            color: AppColors.secondaryForeground,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              '${distance.toStringAsFixed(distance % 1 == 0 ? 0 : 1)}km',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
