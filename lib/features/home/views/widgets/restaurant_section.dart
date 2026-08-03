import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/home/models/restaurant_summary.dart';

import 'restaurant_card.dart';
import 'section_header.dart';

class RestaurantSection extends StatelessWidget {
  const RestaurantSection({
    required this.title,
    required this.restaurants,
    required this.bookmarkedIds,
    required this.onViewAll,
    required this.onBookmark,
    required this.onOpen,
    super.key,
  });

  final String title;
  final List<RestaurantSummary> restaurants;
  final Set<String> bookmarkedIds;
  final VoidCallback onViewAll;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: SectionHeader(title: title, onViewAll: onViewAll),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 220,
            child: ListView.separated(
              key: PageStorageKey<String>('section-$title'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
              ),
              itemCount: restaurants.length,
              separatorBuilder: (context, index) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (context, index) {
                final restaurant = restaurants[index];
                return RestaurantCard(
                  restaurant: restaurant,
                  isBookmarked: bookmarkedIds.contains(restaurant.id),
                  onBookmark: () => onBookmark(restaurant.id),
                  onOpen: () => onOpen(restaurant.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
