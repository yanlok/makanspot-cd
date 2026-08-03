import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/discover_controller.dart';
import '../controllers/discover_state.dart';
import 'widgets/discover_filter_strip.dart';
import 'widgets/discover_restaurant_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({required this.arguments, super.key});

  final DiscoverArguments arguments;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.arguments.query,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverControllerProvider(widget.arguments));
    final controller = ref.read(
      discoverControllerProvider(widget.arguments).notifier,
    );
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _DiscoverHeader(
            searchController: _searchController,
            state: state,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            onSearchChanged: controller.updateSearch,
            onClearSearch: () {
              _searchController.clear();
              controller.updateSearch('');
            },
            onToggleFilter: controller.toggleFilter,
            onToggleCuisine: controller.toggleCuisine,
            onToggleBudget: controller.toggleBudget,
            onSelectSort: controller.selectSort,
          ),
          Expanded(
            child: _DiscoverResults(
              state: state,
              onRetry: controller.load,
              onClear: () {
                _searchController.clear();
                controller.clearFilters();
              },
              onBookmark: controller.toggleBookmark,
              onOpen: (id) => context.go('/restaurant/$id'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.searchController,
    required this.state,
    required this.onBack,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onToggleFilter,
    required this.onToggleCuisine,
    required this.onToggleBudget,
    required this.onSelectSort,
  });

  static const _filters = [
    'Hidden Gems',
    'Open Now',
    'Budget',
    'Mamak',
    'Street Food',
    'Desserts',
    'Near Me',
  ];
  static const _cuisines = [
    'Malay',
    'Chinese',
    'Indian',
    'Nyonya',
    'Western',
    'Japanese',
    'Korean',
    'Street Food',
    'Desserts',
    'Mamak',
  ];
  static const _budgets = ['Low', 'Medium', 'High'];
  static const _sortOptions = [
    'Popularity',
    'Recommendation Score',
    'Distance',
    'Newest Listings',
  ];

  final TextEditingController searchController;
  final DiscoverState state;
  final VoidCallback onBack;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onToggleFilter;
  final ValueChanged<String> onToggleCuisine;
  final ValueChanged<String> onToggleBudget;
  final ValueChanged<String> onSelectSort;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.secondary)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('discover-back'),
                  onPressed: onBack,
                  icon: const Icon(LucideIcons.chevronLeft),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 36,
                  ),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 2),
                Text('Discover', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('discover-search'),
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search restaurants, food, or areas',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: state.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('discover-clear-search'),
                        onPressed: onClearSearch,
                        icon: const Icon(LucideIcons.x, size: 17),
                        tooltip: 'Clear search',
                      ),
              ),
            ),
            const SizedBox(height: 10),
            DiscoverFilterStrip(
              options: _filters,
              selected: state.selectedFilters,
              onToggle: onToggleFilter,
            ),
            const SizedBox(height: 11),
            DiscoverFilterStrip(
              options: _cuisines,
              selected: state.selectedCuisines,
              onToggle: onToggleCuisine,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DiscoverFilterStrip(
                    options: _budgets,
                    selected: state.selectedBudgets,
                    onToggle: onToggleBudget,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 255,
                  child: _SortControl(
                    value: state.sortBy,
                    options: _sortOptions,
                    onChanged: onSelectSort,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SortControl extends StatelessWidget {
  const _SortControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: const ShapeDecoration(
        color: AppColors.secondary,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.slidersHorizontal,
            size: 16,
            color: AppColors.secondaryForeground,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('discover-sort'),
                value: value,
                isDense: true,
                isExpanded: true,
                style: const TextStyle(
                  color: AppColors.secondaryForeground,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (selection) {
                  if (selection != null) {
                    onChanged(selection);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverResults extends StatelessWidget {
  const _DiscoverResults({
    required this.state,
    required this.onRetry,
    required this.onClear,
    required this.onBookmark,
    required this.onOpen,
  });

  final DiscoverState state;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      DiscoverStatus.loading => const _DiscoverLoading(),
      DiscoverStatus.error => _DiscoverMessage(
        icon: LucideIcons.wifiOff,
        title: 'Could not load Discover',
        message: state.errorMessage ?? 'Please try again.',
        actionLabel: 'Try Again',
        onAction: onRetry,
      ),
      DiscoverStatus.empty => _DiscoverMessage(
        icon: LucideIcons.slidersHorizontal,
        title: 'No Restaurants Found',
        message:
            'Try adjusting your search or filters to discover more places.',
        actionLabel: 'Clear Filters',
        onAction: onClear,
      ),
      DiscoverStatus.content => _RestaurantGrid(
        state: state,
        onBookmark: onBookmark,
        onOpen: onOpen,
      ),
    };
  }
}

class _RestaurantGrid extends StatelessWidget {
  const _RestaurantGrid({
    required this.state,
    required this.onBookmark,
    required this.onOpen,
  });

  final DiscoverState state;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final count = state.restaurants.length;
    final filterCount = state.activeFilterCount;
    return CustomScrollView(
      key: const Key('discover-results-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              '$count restaurant${count == 1 ? '' : 's'} found'
              '${filterCount == 0 ? '' : ' · $filterCount '
                        'filter${filterCount == 1 ? '' : 's'} active'}',
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 14,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final restaurant = state.restaurants[index];
              return DiscoverRestaurantCard(
                restaurant: restaurant,
                isBookmarked: state.bookmarkedIds.contains(restaurant.id),
                onBookmark: () => onBookmark(restaurant.id),
                onOpen: () => onOpen(restaurant.id),
              );
            }, childCount: state.restaurants.length),
          ),
        ),
      ],
    );
  }
}

class _DiscoverLoading extends StatelessWidget {
  const _DiscoverLoading();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return DecoratedBox(
          key: const Key('discover-loading-card'),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        );
      },
    );
  }
}

class _DiscoverMessage extends StatelessWidget {
  const _DiscoverMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
