import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Circular user avatar with an initial-letter fallback, used by the user
/// management screens.
class AdminUserAvatar extends StatelessWidget {
  const AdminUserAvatar({
    required this.initial,
    required this.imageUrl,
    this.size = 44,
    super.key,
  });

  final String initial;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryForeground,
          ),
        ),
      ),
    );
    if (imageUrl.isEmpty) {
      return fallback;
    }
    final image = imageUrl.startsWith('assets/')
        ? Image.asset(imageUrl, fit: BoxFit.cover)
        : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    return ClipOval(
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
