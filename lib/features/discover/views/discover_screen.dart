import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/services/location_service.dart';
import '../controllers/discover_controller.dart';
import '../controllers/discover_state.dart';
import 'widgets/discover_filter_sheet.dart';
import 'widgets/discover_restaurant_card.dart';

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

class MapPullUp extends StatefulWidget {
  const MapPullUp({
    required this.state,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onToggleFilter,
    required this.onToggleCuisine,
    required this.onToggleBudget,
    required this.onClearFilters,
    required this.onOpenFilterSheet,
    required this.onOpenRestaurant,
    required this.onToggleBookmark,
    super.key,
  });

  final DiscoverState state;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleFilter;
  final ValueChanged<String> onToggleCuisine;
  final ValueChanged<String> onToggleBudget;
  final VoidCallback onClearFilters;
  final VoidCallback onOpenFilterSheet;
  final ValueChanged<String> onOpenRestaurant;
  final ValueChanged<String> onToggleBookmark;

  @override
  State<MapPullUp> createState() => _MapPullUpState();
}

class _MapPullUpState extends State<MapPullUp> {
  static const int _pageSize = 10;
  int _currentPage = 1;
  bool _isLoadingMore = false;

  late final TextEditingController _searchController = TextEditingController(
    text: widget.state.searchQuery,
  );

  static const _quickCuisines = [
    'Mamak',
    'Cafe',
    'Malay',
    'Chinese',
    'Street Food',
    'Dessert & Bakery',
    'Japanese',
    'Korean',
    'Western',
    'Indian',
    'Seafood',
  ];

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapPullUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    if (oldWidget.state.searchQuery != widget.state.searchQuery &&
        _searchController.text != widget.state.searchQuery) {
      _searchController.text = widget.state.searchQuery;
    }
    if (!listEquals(oldWidget.state.restaurants, widget.state.restaurants) ||
        oldWidget.state.selectedFilters != widget.state.selectedFilters ||
        oldWidget.state.selectedCuisines != widget.state.selectedCuisines ||
        oldWidget.state.selectedBudgets != widget.state.selectedBudgets ||
        oldWidget.state.selectedAreas != widget.state.selectedAreas ||
        oldWidget.state.sortBy != widget.state.sortBy) {
      _currentPage = 1;
      _isLoadingMore = false;
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients || _isLoadingMore) return;
    final pos = widget.scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    final total = widget.state.restaurants.length;
    if (_currentPage * _pageSize >= total) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.microtask(() {
      if (mounted) {
        setState(() {
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = widget.state.restaurants;
    final selectedId = widget.state.selectedRestaurantId;

    if (selectedId != null) {
      final selectedIndex = restaurants.indexWhere((r) => r.id == selectedId);
      if (selectedIndex >= 0) {
        final requiredPage = (selectedIndex ~/ _pageSize) + 1;
        if (requiredPage > _currentPage) {
          _currentPage = requiredPage;
        }
      }
    }

    final visibleCount = math.min(_currentPage * _pageSize, restaurants.length);
    final visibleRestaurants = restaurants.take(visibleCount).toList();
    final hasMore = visibleCount < restaurants.length;

    return Material(
      color: AppColors.surface,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 250) {
            _loadMore();
          }
          return false;
        },
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
                          restaurants.length > _pageSize
                              ? 'Showing ${visibleRestaurants.length} of ${restaurants.length}'
                              : '${restaurants.length} found',
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
                    SingleChildScrollView(
                      key: const Key('discover-quick-filters'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterSheetButton(
                            activeCount: widget.state.activeFilterCount,
                            onPressed: widget.onOpenFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          if (widget.state.activeFilterCount > 0) ...[
                            _QuickFilterChip(
                              icon: LucideIcons.x,
                              label: 'Clear all',
                              isSelected: false,
                              onTap: widget.onClearFilters,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _QuickFilterChip(
                            icon: LucideIcons.bookmark,
                            label: 'Saved',
                            isSelected:
                                widget.state.selectedFilters.contains('Saved'),
                            onTap: () => widget.onToggleFilter('Saved'),
                          ),
                          const SizedBox(width: 8),
                          _QuickFilterChip(
                            label: r'$ Budget',
                            isSelected:
                                widget.state.selectedBudgets.contains('Low'),
                            onTap: () => widget.onToggleBudget('Low'),
                          ),
                          const SizedBox(width: 8),
                          for (final cuisine in _quickCuisines) ...[
                            _QuickFilterChip(
                              label: cuisine,
                              isSelected:
                                  widget.state.selectedCuisines.contains(cuisine),
                              onTap: () => widget.onToggleCuisine(cuisine),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final restaurant = visibleRestaurants[index];
                      final isSelected = restaurant.id == selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 180,
                          child: DiscoverRestaurantCard(
                            restaurant: restaurant,
                            isSelected: isSelected,
                            isBookmarked: widget.state.bookmarkedIds
                                .contains(restaurant.id),
                            onBookmark: () =>
                                widget.onToggleBookmark(restaurant.id),
                            onOpen: () => widget.onOpenRestaurant(restaurant.id),
                          ),
                        ),
                      );
                    },
                    childCount: visibleRestaurants.length,
                  ),
                ),
              ),
              if (hasMore && _isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Loading more restaurants...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (restaurants.length > _pageSize)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Showing all restaurants',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ],
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
  static const String _restaurantsSourceId = 'restaurants-source';

  mp.MapboxMap? _mapboxMap;
  Future<void>? _locationRequest;
  bool _keepUserLocationCamera = false;
  bool _nativeMapLoaded = false;
  bool _isMapReady = false;
  bool _mapLoadFailed = false;
  bool _initialLocationAttempted = false;
  bool _mapInitialized = false;
  final LocationService _locationService = LocationService();

  @override
  void dispose() {
    _mapboxMap = null;
    _mapInitialized = false;
    super.dispose();
  }

  bool _sourceUpdateListenerAttached = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverControllerProvider(widget.arguments));
    if (!_sourceUpdateListenerAttached) {
      _sourceUpdateListenerAttached = true;
      ref.listen(
        discoverControllerProvider(widget.arguments),
        (previous, next) {
          if (_isMapReady && !identical(previous?.restaurants, next.restaurants)) {
            unawaited(_updateMapSource());
          }
        },
      );
    }
    final controller = ref.read(
      discoverControllerProvider(widget.arguments).notifier,
    );
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
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
                        // Creation-time camera avoids a Mapbox lifecycle race
                        // that can discard viewport updates before the
                        // platform map is registered.
                        // ignore: deprecated_member_use
                        cameraOptions: mp.CameraOptions(
                          center: _malaysiaCenter,
                          zoom: _malaysiaZoom,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
            initialChildSize: 0.30,
            minChildSize: 0.12,
            maxChildSize: 0.82,
            snap: true,
            snapSizes: const [0.30, 0.82],
            builder: (context, scrollController) => MapPullUp(
              state: state,
              scrollController: scrollController,
              onSearchChanged: controller.updateSearch,
              onToggleFilter: controller.toggleFilter,
              onToggleCuisine: controller.toggleCuisine,
              onToggleBudget: controller.toggleBudget,
              onClearFilters: controller.clearFilters,
              onOpenFilterSheet: () => showDiscoverFilterSheet(
                context,
                state: state,
                controller: controller,
              ),
              onOpenRestaurant: (id) => context.push('/restaurant/$id'),
              onToggleBookmark: controller.toggleBookmark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    _nativeMapLoaded = false;
    _isMapReady = false;
    _mapLoadFailed = false;
    try {
      _mapboxMap = controller;
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
      await _completeMapInitialization(controller);
    } catch (error, stackTrace) {
      debugPrint('Unable to initialize map: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      setState(() {
        _isMapReady = false;
        _mapLoadFailed = true;
      });
    }
  }

  Future<void> _completeMapInitialization(mp.MapboxMap controller) async {
    if (_mapInitialized || !_nativeMapLoaded || !mounted || !identical(_mapboxMap, controller)) {
      return;
    }
    _mapInitialized = true;
    try {
      await controller.setCamera(
        mp.CameraOptions(center: _malaysiaCenter, zoom: _malaysiaZoom),
      );
      if (!mounted || !identical(_mapboxMap, controller)) {
        return;
      }
      setState(() {
        _isMapReady = true;
        _mapLoadFailed = false;
      });
      await _setupMapLayers(controller);
      unawaited(_updateMapSource());
      if (!_initialLocationAttempted) {
        _initialLocationAttempted = true;
        unawaited(_centerOnCurrentLocation());
      }
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

    // Enable the location layer immediately for visual feedback.
    _keepUserLocationCamera = true;
    await map.location.updateSettings(
      mp.LocationComponentSettings(enabled: true),
    );

    final result = await _locationService.requestCurrentLocation();
    if (!mounted || !identical(_mapboxMap, map)) {
      return;
    }
    if (!result.hasFix) {
      if (_keepUserLocationCamera) {
        await _useMalaysiaCamera(map);
      }
      return;
    }
    await _useUserLocation(map, result.fix!.position);
  }

  Future<void> _useUserLocation(mp.MapboxMap map, gl.Position position) async {
    if (!mounted || !identical(_mapboxMap, map)) {
      return;
    }
    final point = mp.Point(
      coordinates: mp.Position(position.longitude, position.latitude),
    );
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

  /// Renders the orange signboard card to raw RGBA pixels for Mapbox.
  ///
  /// The card is drawn as a rounded pill with a small triangular pointer at
  /// the bottom. Left/right/vertical-center bands stay solid so Mapbox can
  /// 9-patch-stretch the card around text of any length via icon-text-fit.
  Future<mp.MbxImage> _renderSignboardImage() async {
    const width = 44;
    const height = 36;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const radius = 8.0;

    final paint = Paint()..color = const Color(0xFFD96C27);
    final rect = Rect.fromLTWH(0, 0, width.toDouble(), 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      paint,
    );

    // Pointer triangle centered at the bottom edge.
    final pointer = Path()
      ..moveTo(15, 24)
      ..lineTo(29, 24)
      ..lineTo(22, 34)
      ..close();
    canvas.drawPath(pointer, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    // Android's native addStyleImage decodes MbxImage.data with
    // BitmapFactory, so the bytes must be PNG-encoded, not raw RGBA.
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return mp.MbxImage(
      width: width,
      height: height,
      data: data!.buffer.asUint8List(),
    );
  }

  Future<void> _setupMapLayers(mp.MapboxMap map) async {
    final style = map.style;

    // ── GeoJSON source with clustering ──
    if (!await style.styleSourceExists(_restaurantsSourceId)) {
      await style.addStyleSource(
        _restaurantsSourceId,
        jsonEncode({
          'type': 'geojson',
          'data': {'type': 'FeatureCollection', 'features': []},
          'cluster': true,
          'clusterRadius': 50,
          'clusterMaxZoom': 14,
          'clusterMinPoints': 2,
        }),
      );
    }

    // ── Heatmap layer (zoomed-out density view) ──
    if (!await style.styleLayerExists('restaurants-heatmap')) {
      await style.addStyleLayer(
        jsonEncode({
          'id': 'restaurants-heatmap',
          'type': 'heatmap',
          'source': _restaurantsSourceId,
          'maxzoom': 15,
          'paint': {
            'heatmap-opacity': [
              'interpolate', ['linear'], ['zoom'],
              0, 0.6, 10, 0.7, 13, 0.3, 15, 0,
            ],
            'heatmap-radius': [
              'interpolate', ['linear'], ['zoom'],
              0, 2, 8, 12, 12, 25,
            ],
            'heatmap-color': [
              'interpolate', ['linear'], ['heatmap-density'],
              0, 'rgba(217,108,39,0)',
              0.2, 'rgba(217,108,39,0.12)',
              0.5, 'rgba(217,108,39,0.3)',
              0.8, 'rgba(169,71,27,0.5)',
              1, 'rgba(169,71,27,0.7)',
            ],
            'heatmap-weight': [
              'case',
              ['has', 'point_count'],
              ['get', 'point_count'],
              1,
            ],
          },
        }),
        null,
      );
    }

    // ── Cluster circles ──
    if (!await style.styleLayerExists('restaurants-clusters')) {
      await style.addStyleLayer(
        jsonEncode({
          'id': 'restaurants-clusters',
          'type': 'circle',
          'source': _restaurantsSourceId,
          'filter': ['has', 'point_count'],
          'minzoom': 10,
          'maxzoom': 15,
          'paint': {
            'circle-color': [
              'step', ['get', 'point_count'],
              '#D96C27', 100, '#A9471B', 750, '#8B3514',
            ],
            'circle-radius': [
              'step', ['get', 'point_count'],
              18, 100, 26, 750, 34,
            ],
            'circle-opacity': 0.85,
            'circle-stroke-color': '#FFFFFF',
            'circle-stroke-width': 2,
          },
        }),
        null,
      );
    }

    // ── Cluster count labels ──
    if (!await style.styleLayerExists('restaurants-cluster-count')) {
      await style.addStyleLayer(
        jsonEncode({
          'id': 'restaurants-cluster-count',
          'type': 'symbol',
          'source': _restaurantsSourceId,
          'filter': ['has', 'point_count'],
          'minzoom': 10,
          'maxzoom': 15,
          'layout': {
            'text-field': '{point_count_abbreviated}',
            'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
            'text-size': 13,
          },
          'paint': {
            'text-color': '#FFFFFF',
          },
        }),
        null,
      );
    }

    // ── Individual restaurant dots (Mapbox native, stays synced with camera) ──
    if (!await style.styleLayerExists('restaurants-points')) {
      await style.addStyleLayer(
        jsonEncode({
          'id': 'restaurants-points',
          'type': 'circle',
          'source': _restaurantsSourceId,
          'filter': ['!', ['has', 'point_count']],
          'minzoom': 13,
          'paint': {
            'circle-color': '#D96C27',
            'circle-radius': [
              'interpolate', ['linear'], ['zoom'],
              13, 4, 15, 6, 18, 8,
            ],
            'circle-stroke-color': '#FFFFFF',
            'circle-stroke-width': 2,
            'circle-opacity': [
              'interpolate', ['linear'], ['zoom'],
              13, 0, 14, 1,
            ],
          },
        }),
        null,
      );
    }

    // ── Signboard name cards (native, camera-synced) ──
    // A 9-patch-stretchable card image; Mapbox fits each restaurant name
    // inside it with icon-text-fit, with native collision avoidance so
    // overlapping labels are hidden instead of piling up.
    if (await style.getStyleImage('restaurant-signboard') == null) {
      final signboard = await _renderSignboardImage();
      await style.addStyleImage(
        'restaurant-signboard',
        2.0,
        signboard,
        false,
        [
          mp.ImageStretches(first: 12, second: 32), // stretchable middle band (x)
        ],
        [
          mp.ImageStretches(first: 4, second: 20), // stretchable middle band (y)
        ],
        mp.ImageContent(
          left: 6,
          top: 2,
          right: 38,
          bottom: 22, // text content box (l, t, r, b)
        ),
      );
      await style.addStyleLayer(
        jsonEncode({
          'id': 'restaurants-signboards',
          'type': 'symbol',
          'source': _restaurantsSourceId,
          'filter': ['!', ['has', 'point_count']],
          'minzoom': 15,
          'layout': {
            'icon-image': 'restaurant-signboard',
            'icon-text-fit': 'both',
            'icon-text-fit-padding': [5, 9, 7, 9],
            'icon-anchor': 'bottom',
            'text-field': ['get', 'name'],
            'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
            'text-size': 12,
            'text-max-width': 14,
          },
          'paint': {
            'text-color': '#FFFFFF',
            'icon-opacity': [
              'interpolate', ['linear'], ['zoom'],
              15, 0, 15.5, 1,
            ],
          },
        }),
        null,
      );
    }

    // ── Tap listener for clusters and individual markers ──
    // ignore: deprecated_member_use
    map.setOnMapTapListener(_onMapTap);
  }

  Future<void> _updateMapSource() async {
    final map = _mapboxMap;
    if (map == null || !_isMapReady) return;

    final state = ref.read(discoverControllerProvider(widget.arguments));
    final restaurants = state.restaurants;

    final features = restaurants
        .where((r) => r.latitude != null && r.longitude != null)
        .map(
          (r) => {
                'type': 'Feature',
                'id': r.id,
                'geometry': {
                  'type': 'Point',
                  'coordinates': [r.longitude!, r.latitude!],
                },
                'properties': {
                  'id': r.id,
                  'name': r.name,
                },
              },
        )
        .toList();

    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    try {
      final source =
          await map.style.getSource(_restaurantsSourceId) as mp.GeoJsonSource?;
      if (source != null) {
        await source.updateGeoJSON(geoJson);
      }
    } catch (e) {
      debugPrint('Failed to update restaurants source: $e');
    }
  }

  Future<void> _onMapTap(mp.MapContentGestureContext gesture) async {
    final map = _mapboxMap;
    if (map == null || !_isMapReady) return;

    try {
      const interactiveLayers = [
        'restaurants-signboards',
        'restaurants-points',
        'restaurants-clusters',
        'restaurants-cluster-count',
      ];

      final screenCoord = mp.ScreenCoordinate(
        x: gesture.touchPosition.x,
        y: gesture.touchPosition.y,
      );
      var results = await map.queryRenderedFeatures(
        mp.RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        mp.RenderedQueryOptions(layerIds: interactiveLayers),
      );

      // If no feature was found at the exact point, retry with a small touch tolerance box
      if (results.isEmpty) {
        const hitSlop = 22.0;
        results = await map.queryRenderedFeatures(
          mp.RenderedQueryGeometry.fromScreenBox(
            mp.ScreenBox(
              min: mp.ScreenCoordinate(
                x: (gesture.touchPosition.x - hitSlop).clamp(0.0, double.infinity),
                y: (gesture.touchPosition.y - hitSlop).clamp(0.0, double.infinity),
              ),
              max: mp.ScreenCoordinate(
                x: gesture.touchPosition.x + hitSlop,
                y: gesture.touchPosition.y + hitSlop,
              ),
            ),
          ),
          mp.RenderedQueryOptions(layerIds: interactiveLayers),
        );
      }

      if (results.isEmpty) return;

      for (final result in results) {
        final feature = result?.queriedFeature.feature;
        if (feature == null) continue;

        final props = feature['properties'];
        final propsMap = props is Map ? props : null;

        // Cluster tap → zoom in
        if (propsMap != null && propsMap.containsKey('cluster_id')) {
          final expansionZoom = await map.getGeoJsonClusterExpansionZoom(
            _restaurantsSourceId,
            Map<String, Object?>.from(
              propsMap.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
          final zoom = double.tryParse(expansionZoom.value ?? '') ?? 16;
          await map.flyTo(
            mp.CameraOptions(
              center: gesture.point,
              zoom: zoom + 0.5,
            ),
            mp.MapAnimationOptions(duration: 300),
          );
          return;
        }

        // Individual marker / signboard tap → navigate to restaurant
        final restaurantId = propsMap?['id'] ?? feature['id'];
        if (restaurantId != null) {
          final id = restaurantId.toString();
          if (mounted) {
            ref
                .read(discoverControllerProvider(widget.arguments).notifier)
                .selectRestaurant(id);
            context.push('/restaurant/$id');
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Map tap handler error: $e');
    }
  }
}

class _FilterSheetButton extends StatelessWidget {
  const _FilterSheetButton({
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    return Material(
      color: hasActive ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: hasActive
            ? BorderSide.none
            : const BorderSide(color: AppColors.secondary),
      ),
      child: InkWell(
        key: const Key('discover-open-filters'),
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.slidersHorizontal,
                size: 15,
                color: hasActive ? AppColors.surface : AppColors.foreground,
              ),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasActive ? AppColors.surface : AppColors.foreground,
                ),
              ),
              if (hasActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: isSelected
            ? BorderSide.none
            : const BorderSide(color: AppColors.secondary),
      ),
      child: InkWell(
        key: Key('quick-filter-$label'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? AppColors.surface
                      : AppColors.secondaryForeground,
                ),
                const SizedBox(width: 5),
              ] else if (isSelected) ...[
                const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: AppColors.surface,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.surface
                      : AppColors.secondaryForeground,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
