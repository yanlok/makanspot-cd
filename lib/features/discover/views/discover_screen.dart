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
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

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
  late final ScrollController _recommendationsScrollController =
      ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _recommendationsScrollController.dispose();
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
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                        ),
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
                      const Icon(
                        LucideIcons.sparkles,
                        size: 17,
                        color: AppColors.accent,
                      ),
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
                child: Scrollbar(
                  controller: _recommendationsScrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _recommendationsScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    scrollDirection: Axis.horizontal,
                    itemCount: restaurants.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _MapRecommendationCard(
                      restaurant: restaurants[index],
                      onTap: () =>
                          widget.onOpenRestaurant(restaurants[index].id),
                    ),
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
                        const Icon(
                          LucideIcons.star,
                          size: 14,
                          color: AppColors.accent,
                        ),
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
  static final mp.Point _malaysiaCenter = mp.Point(
    coordinates: mp.Position(102.25, 4.2),
  );
  static const double _malaysiaZoom = 6;
  static const double _userLocationZoom = 13.5;
  static const Duration _freshLocationTimeout = Duration(seconds: 6);
  static const Duration _maximumCachedLocationAge = Duration(minutes: 10);

  mp.MapboxMap? _mapboxMap;
  mp.CircleAnnotationManager? _markerManager;
  Future<void> _markerRenderQueue = Future<void>.value();
  int _markerRenderGeneration = 0;
  Future<void>? _locationRequest;
  mp.Point? _userLocation;
  bool _keepUserLocationCamera = false;
  bool _nativeMapLoaded = false;
  bool _mapSetupComplete = false;
  bool _mapInitializationCompleting = false;
  bool _isMapReady = false;
  bool _mapLoadFailed = false;

  late final TextEditingController _searchController = TextEditingController(
    text: widget.arguments.query,
  );

  @override
  void dispose() {
    _markerRenderGeneration++;
    _mapboxMap = null;
    _markerManager = null;
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverControllerProvider(widget.arguments));
    ref.listen<List<DiscoverRestaurant>>(
      discoverControllerProvider(
        widget.arguments,
      ).select((state) => state.restaurants),
      (_, restaurants) {
        if (_isMapReady) {
          _scheduleMarkerRender(restaurants);
        }
      },
    );
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
              onMapLoadedListener: (_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _nativeMapLoaded = true;
                  _mapLoadFailed = false;
                });
                final map = _mapboxMap;
                if (map != null) {
                  unawaited(_completeMapInitialization(map));
                }
              },
              onMapLoadErrorListener: (event) {
                debugPrint('Unable to load map: ${event.message}');
                if (!mounted) {
                  return;
                }
                setState(() {
                  _nativeMapLoaded = false;
                  _isMapReady = false;
                  _mapLoadFailed = true;
                });
              },
              styleUri: mp.MapboxStyles.MAPBOX_STREETS,
              // Creation-time camera avoids a Mapbox lifecycle race that can
              // discard viewport updates before the platform map is registered.
              // ignore: deprecated_member_use
              cameraOptions: mp.CameraOptions(
                center: _malaysiaCenter,
                zoom: _malaysiaZoom,
              ),
            ),
          ),
          if (!_isMapReady)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.background,
                child: Center(
                  child: _mapLoadFailed
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.mapPinned,
                              size: 38,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Could not load the map',
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 12),
                            Text(
                              'Loading map…',
                              style: TextStyle(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                ),
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
          Positioned(
            top: 48,
            right: 16,
            child: _MapActionButton(
              icon: LucideIcons.bookmark,
              tooltip: 'Saved restaurants',
              onPressed: () => context.push('/saved-restaurants'),
            ),
          ),
          Positioned(
            top: 104,
            right: 16,
            child: _MapActionButton(
              icon: LucideIcons.locateFixed,
              tooltip: 'Use current location',
              onPressed: () => unawaited(_centerOnCurrentLocation()),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.18,
            minChildSize: 0.12,
            maxChildSize: 0.82,
            snap: true,
            snapSizes: const [0.18, 0.82],
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
    _nativeMapLoaded = false;
    _mapSetupComplete = false;
    _mapInitializationCompleting = false;
    _isMapReady = false;
    _mapLoadFailed = false;
    try {
      _markerRenderGeneration++;
      _mapboxMap = controller;
      _markerManager = null;
      await Future.wait([
        controller.compass.updateSettings(mp.CompassSettings(enabled: false)),
        controller.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false)),
        controller.logo.updateSettings(
          mp.LogoSettings(
            enabled: true,
            position: mp.OrnamentPosition.TOP_LEFT,
            marginLeft: 16,
            marginTop: 104,
          ),
        ),
        controller.attribution.updateSettings(
          mp.AttributionSettings(
            enabled: true,
            position: mp.OrnamentPosition.TOP_LEFT,
            marginLeft: 108,
            marginTop: 104,
            clickable: true,
          ),
        ),
      ]);
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      final markerManager = await controller.annotations
          .createCircleAnnotationManager();
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      _markerManager = markerManager;
      _mapSetupComplete = true;
      await _completeMapInitialization(controller);
    } catch (error, stackTrace) {
      debugPrint('Unable to initialize map: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      setState(() {
        _mapSetupComplete = false;
        _isMapReady = false;
        _mapLoadFailed = true;
      });
    }
  }

  Future<void> _completeMapInitialization(mp.MapboxMap controller) async {
    if (!_nativeMapLoaded ||
        !_mapSetupComplete ||
        _mapInitializationCompleting ||
        !mounted ||
        !identical(_mapboxMap, controller)) {
      return;
    }

    _mapInitializationCompleting = true;
    try {
      await controller.setCamera(
        mp.CameraOptions(center: _malaysiaCenter, zoom: _malaysiaZoom),
      );
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      var renderedGeneration = 0;
      do {
        final state = ref.read(discoverControllerProvider(widget.arguments));
        final render = _scheduleMarkerRender(
          state.restaurants,
          fitCamera: false,
        );
        renderedGeneration = _markerRenderGeneration;
        await render;
      } while (mounted &&
          identical(_mapboxMap, controller) &&
          renderedGeneration != _markerRenderGeneration);
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      setState(() {
        _isMapReady = true;
        _mapLoadFailed = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to finish map initialization: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      setState(() {
        _isMapReady = false;
        _mapLoadFailed = true;
      });
    } finally {
      if (identical(_mapboxMap, controller)) {
        _mapInitializationCompleting = false;
      }
    }
  }

  Future<void> _centerOnCurrentLocation() {
    final inFlight = _locationRequest;
    if (inFlight != null) {
      return inFlight;
    }

    final operation = _centerOnCurrentLocationInternal();
    _locationRequest = operation;
    return operation.whenComplete(() {
      if (identical(_locationRequest, operation)) {
        _locationRequest = null;
      }
    });
  }

  Future<void> _centerOnCurrentLocationInternal() async {
    final map = _mapboxMap;
    if (map == null || !mounted) {
      return;
    }

    try {
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!mounted || !identical(_mapboxMap, map)) {
        return;
      }
      if (!serviceEnabled) {
        await _useMalaysiaCamera(map);
        return;
      }

      var permission = await gl.Geolocator.checkPermission();
      if (!mounted || !identical(_mapboxMap, map)) {
        return;
      }
      if (permission == gl.LocationPermission.denied) {
        permission = await gl.Geolocator.requestPermission();
        if (!mounted || !identical(_mapboxMap, map)) {
          return;
        }
      }
      if (permission == gl.LocationPermission.denied ||
          permission == gl.LocationPermission.deniedForever) {
        await _useMalaysiaCamera(map);
        return;
      }

      final lastKnownPosition = await gl.Geolocator.getLastKnownPosition();
      if (!mounted || !identical(_mapboxMap, map)) {
        return;
      }
      final cachedPosition =
          lastKnownPosition != null &&
              DateTime.now().difference(lastKnownPosition.timestamp) <=
                  _maximumCachedLocationAge
          ? lastKnownPosition
          : null;
      if (cachedPosition != null) {
        await _useUserLocation(map, cachedPosition);
      }

      try {
        final freshPosition = await gl.Geolocator.getCurrentPosition(
          locationSettings: const gl.LocationSettings(
            accuracy: gl.LocationAccuracy.medium,
            timeLimit: _freshLocationTimeout,
          ),
        );
        if (!mounted || !identical(_mapboxMap, map)) {
          return;
        }
        await _useUserLocation(map, freshPosition);
      } catch (error) {
        debugPrint('Unable to refresh current location: $error');
        if (cachedPosition == null) {
          await _useMalaysiaCamera(map);
        }
      }
    } catch (error) {
      debugPrint('Unable to use current location: $error');
      await _useMalaysiaCamera(map);
    }
  }

  Future<void> _useUserLocation(mp.MapboxMap map, gl.Position position) async {
    if (!mounted || !identical(_mapboxMap, map)) {
      return;
    }
    final point = mp.Point(
      coordinates: mp.Position(position.longitude, position.latitude),
    );
    _userLocation = point;
    _keepUserLocationCamera = true;
    await map.location.updateSettings(
      mp.LocationComponentSettings(enabled: true),
    );
    if (!mounted || !identical(_mapboxMap, map)) {
      return;
    }
    await map.setCamera(
      mp.CameraOptions(center: point, zoom: _userLocationZoom),
    );
  }

  Future<void> _useMalaysiaCamera(mp.MapboxMap map) async {
    if (!mounted || !identical(_mapboxMap, map)) {
      return;
    }
    try {
      _keepUserLocationCamera = false;
      _userLocation = null;
      await map.location.updateSettings(
        mp.LocationComponentSettings(enabled: false),
      );
      if (!mounted || !identical(_mapboxMap, map)) {
        return;
      }
      await map.setCamera(
        mp.CameraOptions(center: _malaysiaCenter, zoom: _malaysiaZoom),
      );
    } catch (error) {
      debugPrint('Unable to use Malaysia map fallback: $error');
    }
  }

  Future<void> _renderMarkers(
    List<DiscoverRestaurant> restaurants,
    int generation,
    bool fitCamera,
  ) async {
    final manager = _markerManager;
    final map = _mapboxMap;
    if (manager == null ||
        map == null ||
        !_isActiveMarkerRender(map, manager, generation)) {
      return;
    }
    final located = restaurants
        .where(
          (restaurant) =>
              restaurant.latitude != null && restaurant.longitude != null,
        )
        .toList();
    await manager.deleteAll();
    if (!_isActiveMarkerRender(map, manager, generation)) {
      return;
    }
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
    if (!_isActiveMarkerRender(map, manager, generation) ||
        !fitCamera ||
        (_keepUserLocationCamera && _userLocation != null)) {
      return;
    }
    if (located.isEmpty) {
      await map.setCamera(
        mp.CameraOptions(center: _malaysiaCenter, zoom: _malaysiaZoom),
      );
    } else if (located.length == 1) {
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
    } else {
      final camera = await map.cameraForCoordinatesPadding(
        located
            .map(
              (restaurant) => mp.Point(
                coordinates: mp.Position(
                  restaurant.longitude!,
                  restaurant.latitude!,
                ),
              ),
            )
            .toList(growable: false),
        mp.CameraOptions(),
        mp.MbxEdgeInsets(top: 80, left: 48, bottom: 260, right: 48),
        13,
        null,
      );
      if (!_isActiveMarkerRender(map, manager, generation) ||
          (_keepUserLocationCamera && _userLocation != null)) {
        return;
      }
      await map.setCamera(camera);
    }
  }

  bool _isActiveMarkerRender(
    mp.MapboxMap map,
    mp.CircleAnnotationManager manager,
    int generation,
  ) {
    return mounted &&
        generation == _markerRenderGeneration &&
        identical(_mapboxMap, map) &&
        identical(_markerManager, manager);
  }

  Future<void> _scheduleMarkerRender(
    List<DiscoverRestaurant> restaurants, {
    bool fitCamera = true,
  }) {
    final snapshot = List<DiscoverRestaurant>.of(restaurants);
    final generation = ++_markerRenderGeneration;
    final operation = _markerRenderQueue.then((_) async {
      if (generation != _markerRenderGeneration) {
        return;
      }
      await _renderMarkers(snapshot, generation, fitCamera);
    });
    _markerRenderQueue = operation.onError((error, stackTrace) {
      debugPrint('Unable to update restaurant markers: $error');
    });
    return operation;
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
