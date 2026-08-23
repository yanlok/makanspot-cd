import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/discover_controller.dart';
import '../controllers/discover_state.dart';
import '../models/discover_restaurant.dart';
import 'widgets/discover_filter_strip.dart';
import 'widgets/discover_restaurant_card.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _MapPullUp extends StatefulWidget {
  const _MapPullUp({
    required this.state,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onToggleFilter,
    required this.onToggleCuisine,
    required this.onToggleBudget,
    required this.onSelectSort,
    required this.onOpenRestaurant,
  });

  final DiscoverState state;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleFilter;
  final ValueChanged<String> onToggleCuisine;
  final ValueChanged<String> onToggleBudget;
  final ValueChanged<String> onSelectSort;
  final ValueChanged<String> onOpenRestaurant;

  @override
  State<_MapPullUp> createState() => _MapPullUpState();
}

class _MapPullUpState extends State<_MapPullUp> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.state.searchQuery,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = widget.state.restaurants;
    return Material(
      color: AppColors.surface,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Explore nearby',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${restaurants.length} found',
                        style: const TextStyle(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('map-search'),
                    controller: _searchController,
                    onChanged: widget.onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search restaurants, food, or areas',
                      prefixIcon: Icon(LucideIcons.search, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DiscoverFilterStrip(
                    options: _DiscoverHeader._filters,
                    selected: widget.state.selectedFilters,
                    onToggle: widget.onToggleFilter,
                  ),
                  const SizedBox(height: 9),
                  DiscoverFilterStrip(
                    options: _DiscoverHeader._cuisines,
                    selected: widget.state.selectedCuisines,
                    onToggle: widget.onToggleCuisine,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: DiscoverFilterStrip(
                          options: _DiscoverHeader._budgets,
                          selected: widget.state.selectedBudgets,
                          onToggle: widget.onToggleBudget,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 155,
                        child: _SortControl(
                          value: widget.state.sortBy,
                          options: _DiscoverHeader._sortOptions,
                          onChanged: widget.onSelectSort,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Recommended for you',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      const Icon(LucideIcons.sparkles, size: 17, color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (restaurants.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Text(
                  'No restaurants match these filters.',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 214,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: restaurants.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _MapRecommendationCard(
                    restaurant: restaurants[index],
                    onTap: () => widget.onOpenRestaurant(restaurants[index].id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapRecommendationCard extends StatelessWidget {
  const _MapRecommendationCard({required this.restaurant, required this.onTap});

  final DiscoverRestaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.secondary),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 105,
                width: double.infinity,
                child: MakanNetworkImage(
                  url: restaurant.imageUrl,
                  semanticLabel: restaurant.name,
                  fallbackKey: Key('map-image-${restaurant.id}'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      restaurant.cuisine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(LucideIcons.star, size: 14, color: AppColors.accent),
                        const SizedBox(width: 3),
                        Text(restaurant.rating?.toStringAsFixed(1) ?? '-'),
                        const SizedBox(width: 8),
                        Text(
                          restaurant.distanceKm == null
                              ? restaurant.budget
                              : '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
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
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({required this.arguments, super.key});

  final DiscoverArguments arguments;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  StreamSubscription? _userPositionStream;
  mp.MapboxMap? _mapboxMap;
  mp.CircleAnnotationManager? _markerManager;

  late final TextEditingController _searchController = TextEditingController(
    text: widget.arguments.query,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_setupPositionTracking());
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverControllerProvider(widget.arguments));
    final controller = ref.read(
      discoverControllerProvider(widget.arguments).notifier,
    );
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: mp.MapWidget(
              key: const Key('discover-map'),
              onMapCreated: _onMapCreated,
              styleUri: mp.MapboxStyles.STANDARD,
            ),
          ),
          Positioned(
            top: 48,
            left: 16,
            child: _MapActionButton(
              icon: LucideIcons.chevronLeft,
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.18,
            maxChildSize: 0.82,
            snap: true,
            snapSizes: const [0.32, 0.82],
            builder: (context, scrollController) => _MapPullUp(
              state: state,
              scrollController: scrollController,
              onSearchChanged: controller.updateSearch,
              onToggleFilter: controller.toggleFilter,
              onToggleCuisine: controller.toggleCuisine,
              onToggleBudget: controller.toggleBudget,
              onSelectSort: controller.selectSort,
              onOpenRestaurant: (id) => context.push('/restaurant/$id'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    try {
      _mapboxMap = controller;
      await _mapboxMap?.location.updateSettings(
        mp.LocationComponentSettings(enabled: true),
      );
      _markerManager = await controller.annotations
          .createCircleAnnotationManager();
      final state = ref.read(discoverControllerProvider(widget.arguments));
      await _renderMarkers(state.restaurants);
    } catch (error) {
      debugPrint('Unable to initialize map: $error');
    }
  }

  Future<void> _renderMarkers(List<DiscoverRestaurant> restaurants) async {
    final manager = _markerManager;
    final map = _mapboxMap;
    if (manager == null || map == null) {
      return;
    }
    final located = restaurants
        .where(
          (restaurant) =>
              restaurant.latitude != null && restaurant.longitude != null,
        )
        .toList();
    await manager.deleteAll();
    await manager.createMulti(
      located.map((restaurant) {
        return mp.CircleAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              restaurant.longitude!,
              restaurant.latitude!,
            ),
          ),
          circleColor: AppColors.primary.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: AppColors.surface.toARGB32(),
          circleStrokeWidth: 3,
        );
      }).toList(),
    );
    if (located.isNotEmpty) {
      await map.setCamera(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
              located.first.longitude!,
              located.first.latitude!,
            ),
          ),
          zoom: 12.5,
        ),
      );
    }
  }

  Future<void> _setupPositionTracking() async {
    try {
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      final permission = await gl.Geolocator.checkPermission();
      if (permission == gl.LocationPermission.denied ||
          permission == gl.LocationPermission.deniedForever) {
        return;
      }

      _userPositionStream?.cancel();
      _userPositionStream = gl.Geolocator.getPositionStream(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        final map = _mapboxMap;
        if (map != null) {
          map.setCamera(
            mp.CameraOptions(
              zoom: 14.0,
              center: mp.Point(
                coordinates: mp.Position(
                  position.longitude,
                  position.latitude,
                ),
              ),
            ),
          );
        }
      }, onError: (Object error, StackTrace stackTrace) {
        debugPrint('Location stream error: $error');
      });
    } catch (error) {
      debugPrint('Unable to track location: $error');
    }
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
    required this.onViewMap,
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
  final VoidCallback onViewMap;

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
            ElevatedButton(
              key: const Key('discover-view-map'),
              onPressed: onViewMap,
              child: const Text('Explore Map'),
            ),
          ],
        ),
      ),
    );
  }
}

class DiscoverMapScreen extends ConsumerStatefulWidget {
  const DiscoverMapScreen({required this.arguments, super.key});

  final DiscoverArguments arguments;

  @override
  ConsumerState<DiscoverMapScreen> createState() => _DiscoverMapScreenState();
}

class _DiscoverMapScreenState extends ConsumerState<DiscoverMapScreen> {
  StreamSubscription? _userPositionStream;
  mp.MapboxMap? _mapboxMap;
  mp.CircleAnnotationManager? _markerManager;

  @override
  void initState() {
    super.initState();
    unawaited(_setupPositionTracking());
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverControllerProvider(widget.arguments));
    ref.listen(discoverControllerProvider(widget.arguments), (_, next) {
      unawaited(_renderMarkers(next.restaurants));
    });
    return Scaffold(
      body: Stack(
        children: [
          mp.MapWidget(
            key: const Key('discover-map'),
            onMapCreated: _onMapCreated,
            styleUri: mp.MapboxStyles.STANDARD,
          ),
          Positioned(
            top: 48,
            left: 16,
            child: _MapActionButton(
              icon: LucideIcons.chevronLeft,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.18,
            maxChildSize: 0.82,
            snap: true,
            snapSizes: const [0.32, 0.82],
            builder: (context, scrollController) => _MapPullUp(
              state: state,
              scrollController: scrollController,
              onSearchChanged: ref
                  .read(discoverControllerProvider(widget.arguments).notifier)
                  .updateSearch,
              onToggleFilter: ref
                  .read(discoverControllerProvider(widget.arguments).notifier)
                  .toggleFilter,
              onToggleCuisine: ref
                  .read(discoverControllerProvider(widget.arguments).notifier)
                  .toggleCuisine,
              onToggleBudget: ref
                  .read(discoverControllerProvider(widget.arguments).notifier)
                  .toggleBudget,
              onSelectSort: ref
                  .read(discoverControllerProvider(widget.arguments).notifier)
                  .selectSort,
              onOpenRestaurant: (id) => context.push('/restaurant/$id'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    try {
      _mapboxMap = controller;
      await _mapboxMap?.location.updateSettings(
        mp.LocationComponentSettings(enabled: true),
      );
        _markerManager = await controller.annotations.createCircleAnnotationManager();
      final state = ref.read(discoverControllerProvider(widget.arguments));
      await _renderMarkers(state.restaurants);
    } catch (error) {
      debugPrint('Unable to initialize map: $error');
    }
  }

  Future<void> _renderMarkers(List<DiscoverRestaurant> restaurants) async {
    final manager = _markerManager;
    final map = _mapboxMap;
    if (manager == null || map == null) {
      return;
    }
    final located = restaurants
      .where((restaurant) => restaurant.latitude != null && restaurant.longitude != null)
      .toList();
    await manager.deleteAll();
    await manager.createMulti(
      located.map((restaurant) {
        return mp.CircleAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(restaurant.longitude!, restaurant.latitude!),
          ),
          circleColor: AppColors.primary.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: AppColors.surface.toARGB32(),
          circleStrokeWidth: 3,
        );
      }).toList(),
    );
    if (located.isNotEmpty) {
      await map.setCamera(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(located.first.longitude!, located.first.latitude!),
          ),
          zoom: 12.5,
        ),
      );
    }
  }

  Future<void> _setupPositionTracking() async {
    try {
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      final permission = await gl.Geolocator.checkPermission();
      if (permission == gl.LocationPermission.denied ||
          permission == gl.LocationPermission.deniedForever) {
        return;
      }

      _userPositionStream?.cancel();
      _userPositionStream = gl.Geolocator.getPositionStream(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        final map = _mapboxMap;
        if (map != null) {
          map.setCamera(
            mp.CameraOptions(
              zoom: 14.0,
              center: mp.Point(
                coordinates: mp.Position(
                  position.longitude,
                  position.latitude,
                ),
              ),
            ),
          );
        }
      }, onError: (Object error, StackTrace stackTrace) {
        debugPrint('Location stream error: $error');
      });
    } catch (error) {
      debugPrint('Unable to track location: $error');
    }
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
