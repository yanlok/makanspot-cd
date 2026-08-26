import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/restaurant_management_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_filter_dropdown.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_search_field.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';

class RestaurantManagementScreen extends ConsumerWidget {
  const RestaurantManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restaurantManagementControllerProvider);
    final controller = ref.read(
      restaurantManagementControllerProvider.notifier,
    );
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('restaurant-management-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const AdminPageHeader(
            title: 'Restaurants',
            subtitle: 'Manage restaurant records',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AdminFilterDropdown<RestaurantVerificationFilter>(
                  width: null,
                  value: state.verificationFilter,
                  options: const [
                    ('All statuses', RestaurantVerificationFilter.all),
                    ('Verified', RestaurantVerificationFilter.verified),
                    ('Pending', RestaurantVerificationFilter.pending),
                  ],
                  onChanged: controller.selectVerificationFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AdminFilterDropdown<RestaurantSort>(
                  width: null,
                  value: state.sort,
                  options: const [
                    ('Name: A–Z', RestaurantSort.nameAscending),
                    ('Name: Z–A', RestaurantSort.nameDescending),
                    ('Rating: High–Low', RestaurantSort.ratingDescending),
                    ('Rating: Low–High', RestaurantSort.ratingAscending),
                    ('Verification status', RestaurantSort.verificationStatus),
                  ],
                  onChanged: controller.selectSort,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AdminSearchField(
                  hint: 'Search restaurants...',
                  value: state.searchQuery,
                  onChanged: controller.updateSearch,
                  fieldKey: const Key('admin-restaurant-search'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                key: const Key('admin-add-restaurant'),
                tooltip: 'Add restaurant',
                onPressed: () => context.go('/admin/restaurants/new'),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  fixedSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (state.status == RestaurantManagementStatus.error)
            _RestaurantManagementError(onRetry: controller.load)
          else if (state.status == RestaurantManagementStatus.loading)
            const AdminListSkeleton(count: 5, cardHeight: 144)
          else if (state.status == RestaurantManagementStatus.empty)
            const AdminEmptyState(
              icon: LucideIcons.utensilsCrossed,
              title: 'No Restaurants Found',
              message: 'No restaurants match your search.',
            )
          else
            for (final restaurant in state.restaurants) ...[
              _RestaurantCard(restaurant: restaurant),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _RestaurantManagementError extends StatelessWidget {
  const _RestaurantManagementError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.triangleAlert,
              size: 44,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            const Text('We could not load restaurant records right now.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});

  final AdminRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('admin-restaurant-${restaurant.id}'),
      onTap: () => context.go('/admin/restaurants/${restaurant.id}'),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RestaurantThumbnail(imageUrl: restaurant.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              restaurant.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminStatusBadge(
                            label: restaurant.verificationStatus,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.ownerName.isEmpty
                            ? (restaurant.description.isEmpty
                                  ? 'Restaurant details not provided'
                                  : restaurant.description)
                            : 'Owner: ${restaurant.ownerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.cuisine.isEmpty
                            ? 'Cuisine not provided'
                            : restaurant.cuisine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              LucideIcons.mapPin,
                              size: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurant.address.isEmpty
                                  ? 'No address'
                                  : restaurant.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedForeground),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.secondary)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      restaurant.sourcePlatform.isEmpty
                          ? 'Manual'
                          : restaurant.sourcePlatform,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.star,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.ratingDisplay,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Manage',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantThumbnail extends StatelessWidget {
  const _RestaurantThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: const Icon(
        LucideIcons.utensilsCrossed,
        size: 24,
        color: AppColors.mutedForeground,
      ),
    );
    if (imageUrl.isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
