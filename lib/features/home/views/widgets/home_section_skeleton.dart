import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Complete loading skeleton for the Home screen, mirroring the latest
/// layout: Spotlight Carousel, Cuisine Browse strip, and curated restaurant sections.
class HomeLoadingSkeleton extends StatefulWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  State<HomeLoadingSkeleton> createState() => _HomeLoadingSkeletonState();
}

class _HomeLoadingSkeletonState extends State<HomeLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.45, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        final opacity = _opacityAnimation.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SpotlightSkeleton(opacity: opacity),
            const SizedBox(height: AppSpacing.large),
            _CuisineBrowseSkeleton(opacity: opacity),
            const SizedBox(height: AppSpacing.large),
            HomeSectionSkeleton(
              titleWidth: 170,
              opacity: opacity,
            ),
            HomeSectionSkeleton(
              titleWidth: 110,
              opacity: opacity,
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightSkeleton extends StatelessWidget {
  const _SpotlightSkeleton({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 90,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 170,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 110,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 58,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              for (var i = 0; i < 4; i++) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CuisineBrowseSkeleton extends StatelessWidget {
  const _CuisineBrowseSkeleton({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 210,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: opacity * 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: opacity),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 44,
                    height: 10,
                    decoration: BoxDecoration(
                      color:
                          AppColors.secondary.withValues(alpha: opacity * 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeSectionSkeleton extends StatelessWidget {
  const HomeSectionSkeleton({
    this.titleWidth = 180,
    this.opacity = 0.65,
    super.key,
  });

  final double titleWidth;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  key: const Key('home-section-skeleton'),
                  width: titleWidth,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 56,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: opacity * 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
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
                  child: Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 128,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: AppColors.secondary
                                    .withValues(alpha: opacity),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  width: 64,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface
                                        .withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 150,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: opacity),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 90,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: opacity * 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary
                                          .withValues(alpha: opacity * 0.7),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 44,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary
                                          .withValues(alpha: opacity * 0.7),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

