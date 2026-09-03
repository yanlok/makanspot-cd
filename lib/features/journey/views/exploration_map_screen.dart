import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/journey_controller.dart';
import '../models/journey_models.dart';
import 'widgets/journey_widgets.dart';

class ExplorationMapScreen extends ConsumerWidget {
  const ExplorationMapScreen({super.key, this.tileProvider});

  /// Injectable for tests; defaults to the network tile provider.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journeyControllerProvider);
    final controller = ref.read(journeyControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          JourneyPageHeader(title: 'Exploration Map', onBack: context.pop),
          Expanded(child: _body(context, state, controller)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    JourneyState state,
    JourneyController controller,
  ) {
    if (state.status == JourneyStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == JourneyStatus.error) {
      return JourneyErrorState(
        message: state.errorMessage!,
        onRetry: controller.load,
      );
    }
    final data = state.data!;
    // Map service unavailable → list-form display (alternative flow A3).
    if (!state.mapAvailable) {
      return _ListFallback(locations: data.locations);
    }
    return ListView(
      key: const Key('exploration-map-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: const Icon(LucideIcons.mapPin, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.locationsWithCoords.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 24),
                ),
                const Text(
                  'Places Visited',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MapPreview(
          locations: state.locationsWithCoords,
          selectedId: state.selectedLocationId,
          onMarkerTap: controller.selectLocation,
          tileProvider: tileProvider,
        ),
        if (state.selectedLocation != null) ...[
          const SizedBox(height: 12),
          _SelectedLocation(
            location: state.selectedLocation!,
            mapsUri: controller.mapsDestination(state.selectedLocation!),
          ),
        ],
        if (state.locationsWithoutCoords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Visits without coordinates',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          for (final location in state.locationsWithoutCoords) ...[
            _LocationTile(
              location: location,
              selected: state.selectedLocationId == location.id,
              onTap: () => controller.selectLocation(location.id),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 16),
        Text(
          'Visited Locations',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        for (final location in data.locations) ...[
          _LocationTile(
            location: location,
            selected: state.selectedLocationId == location.id,
            onTap: () => controller.selectLocation(location.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.locations,
    required this.selectedId,
    required this.onMarkerTap,
    this.tileProvider,
  });

  final List<JourneyLocation> locations;
  final String? selectedId;
  final ValueChanged<String> onMarkerTap;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final points = locations
        .map((location) => LatLng(location.latitude, location.longitude))
        .toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(
        height: 288,
        child: FlutterMap(
          key: const Key('journey-flutter-map'),
          options: MapOptions(
            initialCameraFit: _fitToLocations(points),
            minZoom: 4,
            maxZoom: 18,
            backgroundColor: const Color(0xFFE7E0CF),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.makanspot',
              tileProvider: tileProvider,
            ),
            MarkerLayer(
              markers: [
                for (final location in locations)
                  Marker(
                    point: LatLng(location.latitude, location.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      key: Key('marker-${location.id}'),
                      onTap: () => onMarkerTap(location.id),
                      child: Icon(
                        LucideIcons.mapPin,
                        size: selectedId == location.id ? 36 : 30,
                        color: selectedId == location.id
                            ? AppColors.primaryDark
                            : AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  CameraFit _fitToLocations(List<LatLng> points) {
    if (points.isEmpty) {
      return CameraFit.bounds(
        bounds: LatLngBounds(LatLng(3.139, 101.6869), LatLng(3.139, 101.6869)),
        padding: const EdgeInsets.all(16),
      );
    }
    if (points.length == 1) {
      // Widen a single point so the camera fit has a non-empty area.
      final point = points.first;
      return CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(point.latitude - 0.01, point.longitude - 0.01),
          LatLng(point.latitude + 0.01, point.longitude + 0.01),
        ),
        padding: const EdgeInsets.all(32),
      );
    }
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points.skip(1)) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }
    return CameraFit.bounds(
      bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
      padding: const EdgeInsets.all(48),
    );
  }
}

class _ListFallback extends StatelessWidget {
  const _ListFallback({required this.locations});

  final List<JourneyLocation> locations;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.map, size: 44, color: AppColors.mutedForeground),
              SizedBox(height: 12),
              Text('No Visited Restaurants Yet'),
              SizedBox(height: 6),
              Text(
                'Restaurants you review will appear on your map.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      key: const Key('exploration-map-fallback-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.secondary),
          ),
          child: const Row(
            children: [
              Icon(
                LucideIcons.mapPinOff,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Map is unavailable right now. Showing your visits as a list.',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final location in locations) ...[
          _LocationTile(location: location, selected: false, onTap: () {}),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SelectedLocation extends StatelessWidget {
  const _SelectedLocation({required this.location, required this.mapsUri});

  final JourneyLocation location;
  final Uri mapsUri;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('selected-location-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: SizedBox.square(
              dimension: 56,
              child: MakanNetworkImage(
                url: location.imageUrl,
                semanticLabel: location.name,
                fallbackKey: Key('selected-location-${location.id}'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  location.cuisine,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  location.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in Maps',
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Maps: ${mapsUri.host}'))),
            icon: const Icon(LucideIcons.navigation, size: 18),
          ),
          FilledButton(
            onPressed: () => context.push('/restaurant/${location.id}'),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final JourneyLocation location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('location-${location.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.secondary,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 40,
                child: MakanNetworkImage(
                  url: location.imageUrl,
                  semanticLabel: location.name,
                  fallbackKey: Key('location-fallback-${location.id}'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    location.cuisine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.mapPin, size: 17, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
