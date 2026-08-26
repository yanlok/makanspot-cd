import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/restaurant_details_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_form_widgets.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';

class RestaurantInformationScreen extends ConsumerWidget {
  const RestaurantInformationScreen({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restaurantDetailsControllerProvider(restaurantId));
    final controller = ref.read(
      restaurantDetailsControllerProvider(restaurantId).notifier,
    );
    final restaurant = state.restaurant;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('restaurant-information-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(
            label: 'Back to Restaurants',
            onPressed: () => context.go('/admin/restaurants'),
          ),
          const SizedBox(height: 16),
          const AdminPageHeader(
            title: 'Restaurant Information',
            subtitle: 'Restaurant details and verification status',
          ),
          const SizedBox(height: 20),
          if (state.status == RestaurantDetailsStatus.loading)
            const _RestaurantInformationSkeleton()
          else if (state.status == RestaurantDetailsStatus.notFound)
            const _RestaurantInformationMessage(
              icon: LucideIcons.circleX,
              message: 'Restaurant not found.',
            )
          else if (state.status == RestaurantDetailsStatus.error)
            _RestaurantInformationError(
              message: state.errorMessage!,
              onRetry: controller.load,
            )
          else if (restaurant != null) ...[
            _RestaurantInformationCard(restaurant: restaurant),
            const SizedBox(height: 24),
            AdminPrimaryButton(
              label: 'Edit Restaurant',
              icon: LucideIcons.pencil,
              buttonKey: const Key('admin-restaurant-edit'),
              onPressed: () =>
                  context.go('/admin/restaurants/${restaurant.id}/edit'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RestaurantInformationCard extends StatelessWidget {
  const _RestaurantInformationCard({required this.restaurant});

  final AdminRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RestaurantImage(imageUrl: restaurant.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine.isEmpty
                          ? 'Cuisine not provided'
                          : restaurant.cuisine,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AdminStatusBadge(label: restaurant.verificationStatus),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _InformationSectionTitle('Restaurant Information'),
          _InformationRow(
            icon: LucideIcons.hash,
            label: 'Restaurant ID',
            value: restaurant.displayId,
          ),
          _InformationRow(
            icon: LucideIcons.store,
            label: 'Restaurant Name',
            value: restaurant.name,
          ),
          _InformationRow(
            icon: LucideIcons.mapPin,
            label: 'Address',
            value: _orNotProvided(restaurant.address),
          ),
          _InformationRow(
            icon: LucideIcons.clock3,
            label: 'Operating Hours',
            value: _orNotProvided(restaurant.operatingHours),
          ),
          _InformationRow(
            icon: Icons.restaurant_menu_outlined,
            label: 'Cuisine',
            value: _orNotProvided(restaurant.cuisine),
          ),
          _InformationRow(
            icon: Icons.payments_outlined,
            label: 'Budget',
            value: _orNotProvided(restaurant.budget),
          ),
          _InformationRow(
            icon: LucideIcons.star,
            label: 'Rating',
            value: restaurant.ratingDisplay,
          ),
          _InformationRow(
            icon: Icons.description_outlined,
            label: 'Description',
            value: _orNotProvided(restaurant.description),
          ),
          _InformationRow(
            icon: Icons.public_outlined,
            label: 'Source Platform',
            value: _orNotProvided(restaurant.sourcePlatform),
          ),
          _InformationRow(
            icon: LucideIcons.mapPin,
            label: 'Coordinates',
            value: restaurant.latitude == null || restaurant.longitude == null
                ? 'Not provided'
                : '${restaurant.latitude}, ${restaurant.longitude}',
          ),
          const SizedBox(height: 12),
          const _InformationSectionTitle('Owner Information'),
          _InformationRow(
            icon: LucideIcons.userRound,
            label: 'Owner Name',
            value: _orNotProvided(restaurant.ownerName),
          ),
          _InformationRow(
            icon: LucideIcons.phone,
            label: 'Owner Phone',
            value: _orNotProvided(restaurant.contact),
          ),
          _InformationRow(
            icon: LucideIcons.badgeCheck,
            label: 'Status',
            value: restaurant.verificationStatus,
            last: true,
          ),
        ],
      ),
    );
  }

  static String _orNotProvided(String value) =>
      value.isEmpty ? 'Not provided' : value;
}

class _InformationSectionTitle extends StatelessWidget {
  const _InformationSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RestaurantImage extends StatelessWidget {
  const _RestaurantImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 72,
      height: 72,
      color: AppColors.secondary,
      child: const Icon(
        LucideIcons.utensilsCrossed,
        color: AppColors.mutedForeground,
      ),
    );
    if (imageUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.secondary)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantInformationMessage extends StatelessWidget {
  const _RestaurantInformationMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RestaurantInformationError extends StatelessWidget {
  const _RestaurantInformationError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.triangleAlert,
              size: 44,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _RestaurantInformationSkeleton extends StatelessWidget {
  const _RestaurantInformationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSkeletonBox(height: 72, width: double.infinity, radius: 12),
          SizedBox(height: 20),
          AdminSkeletonBox(height: 48, width: double.infinity, radius: 8),
          SizedBox(height: 12),
          AdminSkeletonBox(height: 48, width: double.infinity, radius: 8),
          SizedBox(height: 12),
          AdminSkeletonBox(height: 48, width: double.infinity, radius: 8),
        ],
      ),
    );
  }
}
