import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class RestaurantMapPreview extends StatelessWidget {
  const RestaurantMapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('restaurant-map-preview'),
      height: 176,
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
