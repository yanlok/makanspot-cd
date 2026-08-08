import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/journey_controller.dart';
import '../models/journey_models.dart';
import 'widgets/journey_widgets.dart';

class ExplorationMapScreen extends ConsumerWidget {
  const ExplorationMapScreen({super.key});

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
    final mapAvailable = data.locations.isNotEmpty &&
        data.locations.every((location) =>
            !location.latitude.isNaN && !location.longitude.isNaN);

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
                  '${data.locations.length}',
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
        _MapSummary(
          locationCount: data.locations.length,
          visitCount: data.visits.length,
          cuisineCount: data.cuisineCount,
        ),
        const SizedBox(height: 16),
        if (mapAvailable) ...[
          _MapPreview(
            locations: data.locations,
            selectedLocationId: state.selectedLocationId,
            onLocationTap: controller.selectLocation,
          ),
        ] else ...[
          _MapUnavailable(locations: data.locations),
        ],
        if (state.selectedLocation != null) ...[
          const SizedBox(height: 12),
          _SelectedLocation(
            location: state.selectedLocation!,
            mapsUri: controller.mapsDestination(state.selectedLocation!),
          ),
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
    required this.selectedLocationId,
    required this.onLocationTap,
  });

  final List<JourneyLocation> locations;
  final String? selectedLocationId;
  final void Function(String id) onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('journey-map-preview'),
      height: 288,
      decoration: BoxDecoration(
        color: const Color(0xFFE7E0CF),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final lats = locations.map((location) => location.latitude);
          final lons = locations.map((location) => location.longitude);
          final minLat = lats.reduce(min);
          final maxLat = lats.reduce(max);
          final minLon = lons.reduce(min);
          final maxLon = lons.reduce(max);
          final latRange = max(0.02, maxLat - minLat);
          final lonRange = max(0.02, maxLon - minLon);
          const markerSize = 34.0;

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE7E0CF), Color(0xFFEDE7DD)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _MapGridPainter(),
                  ),
                ),
              ),
              for (final location in locations)
                Builder(builder: (context) {
                  final x = ((location.longitude - minLon) / lonRange) *
                      (width - markerSize - 40) +
                      20;
                  final y = ((maxLat - location.latitude) / latRange) *
                      (height - markerSize - 40) +
                      20;
                  final left = x.clamp(16.0, width - markerSize - 16.0);
                  final top = y.clamp(16.0, height - markerSize - 16.0);
                  final selected = selectedLocationId == location.id;

                  return Positioned(
                    left: left,
                    top: top,
                    child: GestureDetector(
                      onTap: () => onLocationTap(location.id),
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surface,
                          border: Border.all(
                            color: AppColors.primary,
                            width: selected ? 3 : 2,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.mapPin,
                          size: 18,
                          color: selected ? AppColors.surface : AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }),
              Positioned(
                left: 18,
                bottom: 12,
                right: 18,
                child: Text(
                  'Markers show visited restaurants by coordinate. Tap a marker to review details.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    for (var x = 20.0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 16.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapSummary extends StatelessWidget {
  const _MapSummary({
    required this.locationCount,
    required this.visitCount,
    required this.cuisineCount,
  });

  final int locationCount;
  final int visitCount;
  final int cuisineCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: JourneyStatCard(
            icon: LucideIcons.mapPin,
            value: locationCount,
            label: 'Restaurants',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: JourneyStatCard(
            icon: LucideIcons.plateFork,
            value: cuisineCount,
            label: 'Cuisines',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: JourneyStatCard(
            icon: LucideIcons.calendar,
            value: visitCount,
            label: 'Visits',
          ),
        ),
      ],
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.locations});

  final List<JourneyLocation> locations;

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
            children: const [
              Icon(LucideIcons.wifiOff, color: AppColors.mutedForeground),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Map service unavailable. Showing a list of visited locations instead.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final location in locations) ...[
            _LocationTile(
              location: location,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
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
