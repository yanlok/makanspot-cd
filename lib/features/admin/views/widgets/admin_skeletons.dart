import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class AdminSkeletonBox extends StatelessWidget {
  const AdminSkeletonBox({
    required this.height,
    this.width,
    this.radius = AppRadii.control,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Vertical list of rounded skeleton cards used by the loading states.
class AdminListSkeleton extends StatelessWidget {
  const AdminListSkeleton({
    required this.count,
    required this.cardHeight,
    super.key,
  });

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          AdminSkeletonBox(height: cardHeight, radius: AppRadii.card),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
