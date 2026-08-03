import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(label);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: colors.foreground,
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  _BadgeColors _colorsFor(String status) {
    if (status == 'Open Now' || status == 'Halal') {
      return const _BadgeColors(AppColors.success, AppColors.surface);
    }
    if (status == 'Popular') {
      return const _BadgeColors(AppColors.accent, AppColors.foreground);
    }
    if (status == 'Late Night') {
      return const _BadgeColors(AppColors.primaryDark, AppColors.surface);
    }
    return const _BadgeColors(AppColors.primary, AppColors.surface);
  }
}

class _BadgeColors {
  const _BadgeColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
