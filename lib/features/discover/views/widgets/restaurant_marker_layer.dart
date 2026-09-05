import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

import '../../models/discover_restaurant.dart';
import 'restaurant_map_marker.dart';

class RestaurantMarkerLayer extends StatelessWidget {
  const RestaurantMarkerLayer({
    required this.restaurants,
    required this.selectedId,
    required this.mapboxMap,
    required this.viewportSize,
    required this.onTap,
    super.key,
  });

  final List<DiscoverRestaurant> restaurants;
  final String? selectedId;
  final mp.MapboxMap? mapboxMap;
  final Size viewportSize;
  final ValueChanged<String> onTap;

  /// Only show Flutter signboard markers at this zoom level and above.
  static const double _minZoomForSignboards = 15;

  static const int _maxVisibleMarkers = 15;

  @override
  Widget build(BuildContext context) {
    if (mapboxMap == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<_ProjectionResult>(
      future: _project(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final result = snapshot.data!;
        if (result.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: result.items
              .map(
                (item) => Positioned(
                  // Card + connector (~32px tall) floating just above the
                  // native Mapbox dot at this pixel position.
                  left: item.pixel.dx - 75,
                  top: item.pixel.dy - 42,
                  child: GestureDetector(
                    onTap: () => onTap(item.restaurant.id),
                    child: RestaurantMapMarker(
                      name: item.restaurant.name,
                      isSelected: item.restaurant.id == selectedId,
                      onTap: () => onTap(item.restaurant.id),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Future<_ProjectionResult> _project() async {
    final map = mapboxMap;
    if (map == null) {
      return const _ProjectionResult(items: []);
    }

    // Don't show signboards when zoomed out — Mapbox handles heatmap/clusters.
    final camera = await map.getCameraState();
    if (camera.zoom < _minZoomForSignboards) {
      return const _ProjectionResult(items: []);
    }

    final located = restaurants
        .where((r) => r.latitude != null && r.longitude != null)
        .toList(growable: false);

    if (located.isEmpty) {
      return const _ProjectionResult(items: []);
    }

    final center = camera.center;

    final items = <_ProjectedItem>[];
    for (final restaurant in located) {
      try {
        final screen = await map.pixelForCoordinate(
          mp.Point(
            coordinates: mp.Position(
              restaurant.longitude!,
              restaurant.latitude!,
            ),
          ),
        );
        final dx = restaurant.longitude! - center.coordinates.lng;
        final dy = restaurant.latitude! - center.coordinates.lat;
        items.add(
          _ProjectedItem(
            restaurant: restaurant,
            pixel: Offset(screen.x.toDouble(), screen.y.toDouble()),
            distance: dx * dx + dy * dy,
          ),
        );
      } catch (_) {
        // Skip restaurants that fail to project.
      }
    }

    items.sort((a, b) => a.distance.compareTo(b.distance));

    // Prioritize the selected restaurant, then fill by proximity.
    final visible = <_ProjectedItem>[];
    if (selectedId != null) {
      final selected = items
          .where((item) => item.restaurant.id == selectedId)
          .firstOrNull;
      if (selected != null) {
        visible.add(selected);
      }
    }
    final remaining = _maxVisibleMarkers - visible.length;
    for (var i = 0;
        i < remaining && i + visible.length < items.length;
        i++) {
      final candidate = items[i];
      if (visible.any((v) => v.restaurant.id == candidate.restaurant.id)) {
        continue;
      }
      if (_isInViewport(candidate.pixel, viewportSize)) {
        visible.add(candidate);
      }
    }

    return _ProjectionResult(items: visible);
  }

  bool _isInViewport(Offset pixel, Size size) {
    const margin = 80.0;
    return pixel.dx >= -margin &&
        pixel.dx <= size.width + margin &&
        pixel.dy >= -margin &&
        pixel.dy <= size.height + margin;
  }
}

class _ProjectionResult {
  const _ProjectionResult({required this.items});

  final List<_ProjectedItem> items;
}

class _ProjectedItem {
  const _ProjectedItem({
    required this.restaurant,
    required this.pixel,
    required this.distance,
  });

  final DiscoverRestaurant restaurant;
  final Offset pixel;
  final double distance;
}
