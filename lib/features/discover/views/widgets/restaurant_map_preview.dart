import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

import 'package:makanspot/core/theme/app_theme.dart';

class RestaurantMapPreview extends StatefulWidget {
  const RestaurantMapPreview({
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final double latitude;
  final double longitude;

  @override
  State<RestaurantMapPreview> createState() => _RestaurantMapPreviewState();
}

class _RestaurantMapPreviewState extends State<RestaurantMapPreview> {
  bool _mapLoadFailed = false;

  bool get _hasValidCoords =>
      widget.latitude.isFinite && widget.longitude.isFinite;

  @override
  Widget build(BuildContext context) {
    if (!_hasValidCoords || _mapLoadFailed) {
      return _Placeholder(height: 176);
    }

    return SizedBox(
      key: const Key('restaurant-map-preview'),
      height: 176,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondary),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: mp.MapWidget(
                  key: ValueKey('map-${widget.latitude}-${widget.longitude}'),
                  onMapCreated: _onMapCreated,
                  onMapLoadErrorListener: (_) {
                    if (mounted) setState(() => _mapLoadFailed = true);
                  },
                  styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                  // ignore: deprecated_member_use
                  cameraOptions: mp.CameraOptions(
                    center: mp.Point(
                      coordinates: mp.Position(
                        widget.longitude,
                        widget.latitude,
                      ),
                    ),
                    zoom: 15,
                  ),
                ),
              ),
              // Attribution bar at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\u00A9 OpenStreetMap contributors \u00B7 \u00A9 Mapbox',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    await Future.wait([
      controller.compass.updateSettings(mp.CompassSettings(enabled: false)),
      controller.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false)),
      controller.logo.updateSettings(mp.LogoSettings(enabled: true)),
      controller.attribution.updateSettings(
        mp.AttributionSettings(enabled: true),
      ),
    ]);
  }
}

/// Fallback placeholder shown when coordinates are unavailable, the map
/// fails to load, or the environment is headless/test.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('restaurant-map-preview'),
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: const _MapGridPainter())),
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8)],
              ),
              child: SizedBox.square(
                dimension: 38,
                child: Icon(
                  LucideIcons.mapPin,
                  color: AppColors.surface,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
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
    for (var x = 24.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 24.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
