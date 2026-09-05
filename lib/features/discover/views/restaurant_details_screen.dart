import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/services/maps_launcher.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/discover_controller.dart';
import '../controllers/restaurant_details_controller.dart';
import '../controllers/restaurant_details_state.dart';
import '../models/discover_restaurant.dart';
import 'widgets/restaurant_info_card.dart';
import 'widgets/restaurant_map_preview.dart';
import 'widgets/restaurant_review_card.dart';

class RestaurantDetailsScreen extends ConsumerWidget {
  const RestaurantDetailsScreen({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restaurantDetailsControllerProvider(restaurantId));
    final controller = ref.read(
      restaurantDetailsControllerProvider(restaurantId).notifier,
    );
    return switch (state.status) {
      RestaurantDetailsStatus.loading => const _DetailsLoading(),
      RestaurantDetailsStatus.notFound => const _DetailsMessage(
        icon: LucideIcons.info,
        title: 'Restaurant Not Found',
        message: 'This restaurant may have been removed.',
      ),
      RestaurantDetailsStatus.error => _DetailsMessage(
        icon: LucideIcons.wifiOff,
        title: 'Could not load restaurant',
        message: state.errorMessage ?? 'Please try again.',
        actionLabel: 'Try Again',
        onAction: controller.load,
      ),
      RestaurantDetailsStatus.content => _DetailsContent(
        state: state,
        isSaved: ref.watch(savedRestaurantIdsProvider).contains(restaurantId),
        onToggleSave: () {
          final savedIds = Set<String>.of(ref.read(savedRestaurantIdsProvider));
          if (!savedIds.add(restaurantId)) {
            savedIds.remove(restaurantId);
          }
          ref.read(savedRestaurantIdsProvider.notifier).state =
              Set.unmodifiable(savedIds);
        },
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/discover');
          }
        },
        onOpenMaps: () async {
          final restaurant = ref
              .read(restaurantDetailsControllerProvider(restaurantId))
              .restaurant;
          final url = buildGoogleMapsUrl(
            googleMapsUrl: restaurant?.googleMapsUrl,
            latitude: restaurant?.latitude,
            longitude: restaurant?.longitude,
            name: restaurant?.name,
            address: restaurant?.address,
          );
          if (url == null) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No location information available for this restaurant.',
                ),
              ),
            );
            return;
          }
          final result = await launchGoogleMaps(url);
          if (!context.mounted) return;
          if (!result.isSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
          }
        },
        onWriteReview: () {
          context.push('/review/create?restaurant=$restaurantId');
        },
        onReviewLike: controller.toggleReviewLike,
        onOpenReview: (id) => context.push('/post/$id'),
      ),
    };
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.state,
    required this.isSaved,
    required this.onToggleSave,
    required this.onBack,
    required this.onOpenMaps,
    required this.onWriteReview,
    required this.onReviewLike,
    required this.onOpenReview,
  });

  final RestaurantDetailsState state;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onBack;
  final VoidCallback onOpenMaps;
  final VoidCallback onWriteReview;
  final ValueChanged<String> onReviewLike;
  final ValueChanged<String> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final restaurant = state.restaurant!;
    return CustomScrollView(
      key: const Key('restaurant-details-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: _RestaurantHero(restaurant: restaurant, onBack: onBack),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.list(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('restaurant-details-save'),
                    onPressed: onToggleSave,
                    tooltip: isSaved
                        ? 'Remove from saved restaurants'
                        : 'Save restaurant',
                    icon: Icon(
                      isSaved
                          ? LucideIcons.bookmarkCheck
                          : LucideIcons.bookmark,
                      color: isSaved
                          ? AppColors.primary
                          : AppColors.secondaryForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                restaurant.cuisine,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _RestaurantStats(restaurant: restaurant),
              const SizedBox(height: 16),
              Text(
                restaurant.description,
                style: const TextStyle(fontSize: 14, height: 1.55),
              ),
              const SizedBox(height: 16),
              RestaurantInfoCard(restaurant: restaurant),
              if (restaurant.latitude != null &&
                  restaurant.longitude != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Store Location',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                RestaurantMapPreview(
                  latitude: restaurant.latitude!,
                  longitude: restaurant.longitude!,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('open-in-maps'),
                  onPressed: onOpenMaps,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                  ),
                  icon: const Icon(LucideIcons.externalLink, size: 17),
                  label: const Text('Open in Maps'),
                ),
              ),
              const SizedBox(height: 24),
              _ReviewsHeader(
                onWriteReview: onWriteReview,
                showWriteReview: state.reviews.isNotEmpty,
              ),
              const SizedBox(height: 12),
              if (state.reviews.isEmpty)
                _NoReviews(onWriteReview: onWriteReview)
              else
                ...state.reviews.map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RestaurantReviewCard(
                      review: review,
                      onLike: () => onReviewLike(review.id),
                      onOpen: () => onOpenReview(review.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({required this.restaurant, required this.onBack});

  final DiscoverRestaurant restaurant;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 216 + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MakanNetworkImage(
            url: restaurant.imageUrl,
            semanticLabel: restaurant.name,
            fallbackKey: const Key('restaurant-hero-fallback'),
          ),
          Positioned(
            top: topInset > 0 ? topInset + 8 : 16,
            left: 16,
            child: Material(
              color: AppColors.surface.withValues(alpha: 0.92),
              elevation: 1,
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('restaurant-details-back'),
                onPressed: onBack,
                icon: const Icon(LucideIcons.chevronLeft, size: 20),
                tooltip: 'Back',
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: restaurant.labels
                  .map((label) => _HeroBadge(label: label))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD93B2921),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.surface,
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RestaurantStats extends StatelessWidget {
  const _RestaurantStats({required this.restaurant});

  final DiscoverRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (restaurant.rating case final rating?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.star, size: 17, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        Text(
          'Budget: ${restaurant.budget}',
          style: const TextStyle(
            color: AppColors.secondaryForeground,
            fontSize: 14,
          ),
        ),
        if (restaurant.distanceKm case final distance?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 14,
                color: AppColors.secondaryForeground,
              ),
              const SizedBox(width: 4),
              Text(
                '${distance.toStringAsFixed(1)}km away',
                style: const TextStyle(
                  color: AppColors.secondaryForeground,
                  fontSize: 14,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({
    required this.onWriteReview,
    this.showWriteReview = true,
  });

  final VoidCallback onWriteReview;
  final bool showWriteReview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Community Reviews',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
        ),
        if (showWriteReview)
          TextButton.icon(
            key: const Key('write-review'),
            onPressed: onWriteReview,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(LucideIcons.penLine, size: 16),
            label: const Text('Write Review'),
          ),
      ],
    );
  }
}

class _NoReviews extends StatelessWidget {
  const _NoReviews({required this.onWriteReview});

  final VoidCallback onWriteReview;

  @override
  Widget build(BuildContext context) {
    return _DetailsMessage(
      icon: LucideIcons.penLine,
      title: 'No Reviews Yet',
      message: 'Be the first to share your experience at this restaurant.',
      actionLabel: 'Write Review',
      onAction: onWriteReview,
    );
  }
}

class _DetailsLoading extends StatelessWidget {
  const _DetailsLoading();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ListView(
      key: const Key('restaurant-details-loading'),
      children: [
        SizedBox(
          height: 216 + topInset,
          child: const ColoredBox(color: AppColors.secondary),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 250, height: 30, color: AppColors.secondary),
              const SizedBox(height: 12),
              Container(width: 160, height: 18, color: AppColors.secondary),
              const SizedBox(height: 16),
              Container(height: 90, color: AppColors.secondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsMessage extends StatelessWidget {
  const _DetailsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.primary),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
