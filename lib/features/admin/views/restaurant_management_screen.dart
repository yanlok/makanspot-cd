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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            final metrics = notification.metrics;
            // Only paginate when the list actually scrolls; on a short list
            // maxScrollExtent is 0 and every scroll gesture would otherwise
            // trigger a page fetch.
            final atEnd = metrics.maxScrollExtent > 0 &&
                metrics.pixels >= metrics.maxScrollExtent - 40;
            if (atEnd) {
              controller.loadMore();
            }
          }
          return false;
        },
        child: ListView.builder(
          key: const Key('restaurant-management-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          itemCount: _itemCount(state),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHeader(context, ref, controller, state);
            }
            final restaurantIndex = index - 1;
            if (restaurantIndex < state.restaurants.length) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RestaurantCard(restaurant: state.restaurants[restaurantIndex]),
                  const SizedBox(height: 12),
                ],
              );
            }

            return _buildFooter(controller, state);
          },
        ),
      ),
    );
  }

  int _itemCount(RestaurantManagementState state) {
    final hasList = state.status != RestaurantManagementStatus.loading;
    final footer = hasList ? 1 : 0;
    return 1 + (hasList ? state.restaurants.length : 0) + footer;
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    RestaurantManagementController controller,
    RestaurantManagementState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminPageHeader(
          title: 'Restaurants',
          subtitle: 'Manage restaurant records',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AdminFilterDropdown<RestaurantStatusFilter>(
                width: null,
                value: state.statusFilter,
                options: const [
                  ('All restaurants', RestaurantStatusFilter.all),
                  ('Active', RestaurantStatusFilter.active),
                  ('Deleted', RestaurantStatusFilter.deleted),
                ],
                onChanged: controller.selectStatusFilter,
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
                ],
                onChanged: controller.selectSort,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AdminSearchField(
          hint: 'Search restaurants...',
          value: state.searchQuery,
          onChanged: controller.updateSearch,
          fieldKey: const Key('admin-restaurant-search'),
        ),
        const SizedBox(height: 20),
        if (state.status == RestaurantManagementStatus.loading)
          const AdminListSkeleton(count: 5, cardHeight: 144)
        else if (state.status == RestaurantManagementStatus.empty)
          const AdminEmptyState(
            icon: LucideIcons.utensilsCrossed,
            title: 'No Restaurants Found',
            message: 'No restaurants match your filters.',
          ),
      ],
    );
  }

  Widget _buildFooter(
    RestaurantManagementController controller,
    RestaurantManagementState state,
  ) {
    if (state.status == RestaurantManagementStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.triangleAlert,
              size: 24,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 8),
            Text(
              state.pageError ?? 'We could not load restaurant records right now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.loadFirstPage,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (state.status == RestaurantManagementStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.pageError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load more restaurants.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.loadMore,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!state.hasMore && state.restaurants.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'All restaurants loaded.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      );
    }

    return const SizedBox.shrink();
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.isDeleted
                            ? 'Deleted'
                            : ((restaurant.instagramUsername ?? '').isEmpty
                                ? 'Instagram not provided'
                                : 'IG: ${restaurant.instagramUsername}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: restaurant.isDeleted
                              ? AppColors.destructive
                              : AppColors.mutedForeground,
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
                              (restaurant.address ?? '').isEmpty
                                  ? 'No address'
                                  : restaurant.address!,
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
                      restaurant.categoriesDisplay,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  if (restaurant.priceRange != null) ...[
                    const Icon(
                      LucideIcons.star,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      restaurant.priceRange!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
