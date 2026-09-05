import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/profile/models/profile_models.dart';

/// Renders a profile picture that works with both a hosted avatar URL
/// (from Supabase storage) and a bundled asset fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.profileAsset,
    this.size = 96,
    this.padding = 4,
    super.key,
  });

  final String profileAsset;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final isNetwork = profileAsset.startsWith('http');
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(padding),
        color: AppColors.surface,
        child: ClipOval(child: isNetwork ? _networkImage() : _assetImage()),
      ),
    );
  }

  Widget _networkImage() {
    return Image.network(
      profileAsset,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          return child;
        }
        return const ColoredBox(
          color: AppColors.secondary,
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          Image.asset(defaultProfileAsset, fit: BoxFit.cover),
    );
  }

  Widget _assetImage() {
    return Image.asset(
      profileAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _AvatarFallback(),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.secondary,
      child: Center(
        child: Icon(
          LucideIcons.user,
          size: 32,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}
