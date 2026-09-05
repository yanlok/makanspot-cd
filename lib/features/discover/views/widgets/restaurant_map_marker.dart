import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Just the signboard name card shown above a Mapbox-rendered restaurant dot.
/// The dot itself is drawn natively by Mapbox — this widget adds only the
/// floating name label so it can never duplicate the marker.
class RestaurantMapMarker extends StatelessWidget {
  const RestaurantMapMarker({
    required this.name,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Signboard card ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            constraints: const BoxConstraints(maxWidth: 150),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryDark : AppColors.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: Colors.white,
              ),
            ),
          ),
          // ── Connector pointing at the native dot below ──
          CustomPaint(
            size: const Size(14, 7),
            painter: _SignboardConnectorPainter(
              color: isSelected ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignboardConnectorPainter extends CustomPainter {
  _SignboardConnectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SignboardConnectorPainter old) {
    return old.color != color;
  }
}
