import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Status pill mirroring the prototype's StatusBadge colour semantics.
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(label.toLowerCase());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.foreground,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  _BadgeColors _colorsFor(String status) {
    if (status == 'active' || status == 'verified' || status == 'open') {
      return _BadgeColors(
        AppColors.success.withValues(alpha: 0.15),
        AppColors.success,
      );
    }
    if (status == 'pending' || status == 'trending') {
      return _BadgeColors(
        AppColors.accent.withValues(alpha: 0.15),
        AppColors.foreground,
      );
    }
    if (status == 'removed' || status == 'deactivated' || status == 'error') {
      return _BadgeColors(
        AppColors.destructive.withValues(alpha: 0.15),
        AppColors.destructive,
      );
    }
    return _BadgeColors(AppColors.secondary, AppColors.mutedForeground);
  }
}

class _BadgeColors {
  const _BadgeColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
