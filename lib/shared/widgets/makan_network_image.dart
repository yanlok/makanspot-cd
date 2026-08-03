import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class MakanNetworkImage extends StatelessWidget {
  const MakanNetworkImage({
    required this.url,
    required this.semanticLabel,
    required this.fallbackKey,
    super.key,
  });

  final String url;
  final String semanticLabel;
  final Key fallbackKey;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _ImageFallback(key: fallbackKey);
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
        return _ImageFallback(key: fallbackKey);
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.secondary,
      child: Center(
        child: Icon(
          LucideIcons.mapPin,
          size: 32,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}
