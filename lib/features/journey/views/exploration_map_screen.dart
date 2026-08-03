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
        _MapPreview(locations: data.locations),
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
  const _MapPreview({required this.locations});

  final List<JourneyLocation> locations;

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
      child: Stack(
        children: [
          for (var i = 0; i < 8; i++)
            Positioned(
              left: i.isEven ? 18 : 130,
              top: 24.0 + i * 30,
              child: Transform.rotate(
                angle: i.isEven ? 0.25 : -0.35,
                child: Container(
                  width: 210,
                  height: 2,
                  color: AppColors.surface.withValues(alpha: 0.75),
                ),
              ),
            ),
          const Center(
            child: Icon(LucideIcons.map, size: 72, color: Color(0x40927B6B)),
          ),
          for (var index = 0; index < locations.length; index++)
            Positioned(
              left: 90.0 + index * 135,
              top: 90.0 + index * 70,
              child: const Icon(
                LucideIcons.mapPin,
                size: 34,
                color: AppColors.primary,
              ),
            ),
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
