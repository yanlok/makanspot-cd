import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/home_controller.dart';
import '../controllers/home_state.dart';
import '../models/home_feed.dart';
import 'widgets/home_header.dart';
import 'widgets/home_section_skeleton.dart';
import 'widgets/restaurant_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const Key('home-scroll-view'),
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeader(
              greeting: state.greeting,
              firstName: state.feed?.firstName ?? 'Yih',
              location: state.feed?.location ?? 'Kuala Lumpur',
              profileAsset:
                  state.feed?.profileAsset ?? 'assets/images/default_icon.jpg',
              onSearch: (query) {
                final destination = controller.searchDestination(query);
                if (destination != null) {
                  context.go(destination.toString());
                }
              },
              onFilter: (filter) {
                context.go(controller.filterDestination(filter).toString());
              },
              onProfile: () => context.go('/profile'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.large)),
          SliverToBoxAdapter(child: _HomeBody(state: state)),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.status) {
      HomeStatus.loading => const Column(
        children: [
          HomeSectionSkeleton(),
          HomeSectionSkeleton(),
          HomeSectionSkeleton(),
          HomeSectionSkeleton(),
        ],
      ),
      HomeStatus.empty => const _HomeMessage(
        icon: LucideIcons.utensilsCrossed,
        title: 'No makan spots yet',
        message: 'New recommendations will appear here soon.',
      ),
      HomeStatus.error => _HomeMessage(
        icon: LucideIcons.wifiOff,
        title: 'Could not load Home',
        message: state.errorMessage ?? 'Please try again.',
        actionLabel: 'Try Again',
        onAction: ref.read(homeControllerProvider.notifier).load,
      ),
      HomeStatus.content => _HomeSections(
        feed: state.feed!,
        bookmarkedIds: state.bookmarkedIds,
      ),
    };
  }
}

class _HomeSections extends ConsumerWidget {
  const _HomeSections({required this.feed, required this.bookmarkedIds});

  final HomeFeed feed;
  final Set<String> bookmarkedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(homeControllerProvider.notifier);
    void viewSection(String section) {
      context.go(
        Uri(
          path: '/discover',
          queryParameters: {'section': section},
        ).toString(),
      );
    }

    void openRestaurant(String restaurantId) {
      context.go('/restaurant/$restaurantId');
    }

    return Column(
      children: [
        RestaurantSection(
          title: 'Recommended for You',
          restaurants: feed.recommended,
          bookmarkedIds: bookmarkedIds,
          onViewAll: () => viewSection('recommended'),
          onBookmark: controller.toggleBookmark,
          onOpen: openRestaurant,
        ),
        RestaurantSection(
          title: 'Hidden Gems Sekitar Anda',
          restaurants: feed.hiddenGems,
          bookmarkedIds: bookmarkedIds,
          onViewAll: () => viewSection('hidden_gems'),
          onBookmark: controller.toggleBookmark,
          onOpen: openRestaurant,
        ),
        RestaurantSection(
          title: 'Sedap Dekat Sini',
          restaurants: feed.nearby,
          bookmarkedIds: bookmarkedIds,
          onViewAll: () => viewSection('nearby'),
          onBookmark: controller.toggleBookmark,
          onOpen: openRestaurant,
        ),
        RestaurantSection(
          title: 'Newest Listings',
          restaurants: feed.newest,
          bookmarkedIds: bookmarkedIds,
          onViewAll: () => viewSection('newest'),
          onBookmark: controller.toggleBookmark,
          onOpen: openRestaurant,
        ),
      ],
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.primary),
          const SizedBox(height: AppSpacing.medium),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.small),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.medium),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
