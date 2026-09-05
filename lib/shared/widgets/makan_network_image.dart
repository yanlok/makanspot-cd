import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class MakanNetworkImage extends StatelessWidget {
  const MakanNetworkImage({
    required this.url,
    required this.semanticLabel,
    this.fallbackKey,
    this.fallbackIcon = LucideIcons.utensils,
    this.fallbackIconSize = 24,
    super.key,
  });

  final String url;
  final String semanticLabel;
  final Key? fallbackKey;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _ImageFallback(
        key: fallbackKey,
        icon: fallbackIcon,
        iconSize: fallbackIconSize,
      );
    }
    return Image.network(
      url,
      semanticLabel: semanticLabel,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          return child;
        }
        return const ColoredBox(
          color: AppColors.secondary,
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _ImageFallback(
          key: fallbackKey,
          icon: fallbackIcon,
          iconSize: fallbackIconSize,
        );
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    this.icon = LucideIcons.utensils,
    this.iconSize = 24,
    super.key,
  });

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.secondary,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}
