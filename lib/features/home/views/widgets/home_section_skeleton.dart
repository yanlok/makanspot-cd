import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class HomeSectionSkeleton extends StatelessWidget {
  const HomeSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: Container(
              key: const Key('home-section-skeleton'),
              width: 180,
              height: 20,
              decoration: _decoration(8),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
              ),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 256,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 128, decoration: _decoration(16)),
                      const SizedBox(height: 10),
                      Container(
                        width: 180,
                        height: 14,
                        decoration: _decoration(5),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: 110,
                        height: 12,
                        decoration: _decoration(5),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _decoration(double radius) {
    return BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
