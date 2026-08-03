import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/journey_controller.dart';
import '../models/journey_models.dart';
import 'widgets/journey_widgets.dart';

class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journeyControllerProvider);
    final controller = ref.read(journeyControllerProvider.notifier);
    if (state.status == JourneyStatus.loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (state.status == JourneyStatus.error) {
      return SafeArea(
        child: JourneyErrorState(
          message: state.errorMessage!,
          onRetry: controller.load,
        ),
      );
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('journey-scroll'),
        children: [
          _JourneyHero(data: state.data!, onBack: context.pop),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: _JourneyContent(data: state.data!),
          ),
        ],
      ),
    );
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.data, required this.onBack});

  final JourneyData data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              color: AppColors.surface,
              icon: const Icon(LucideIcons.chevronLeft),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      data.user.profileAsset,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.surface),
                        ),
                        Text(
                          data.user.profileTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.surface.withValues(alpha: 0.8),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Score',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.surface.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                        ),
                        Text(
                          '${data.user.communityScore}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.surface,
                                fontSize: 30,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.trendingUp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyContent extends StatelessWidget {
  const _JourneyContent({required this.data});

  final JourneyData data;

  @override
  Widget build(BuildContext context) {
    final earned = data.achievementProgress
        .where((item) => item.earned)
        .take(3)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exploration Overview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            JourneyStatCard(
              icon: LucideIcons.utensils,
              value: data.visits.length,
              label: 'Restaurants Visited',
            ),
            JourneyStatCard(
              icon: LucideIcons.penLine,
              value: data.reviewCount,
              label: 'Reviews Submitted',
            ),
            JourneyStatCard(
              icon: LucideIcons.compass,
              value: data.cuisineCount,
              label: 'Cuisines Explored',
            ),
            JourneyStatCard(
              icon: LucideIcons.star,
              value: data.totalLikes,
              label: 'Total Likes Received',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ProgressToTitle(score: data.user.communityScore),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Achievements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/achievements'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in earned) ...[
          AchievementProgressCard(progress: item),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        JourneyMenuTile(
          icon: LucideIcons.calendar,
          label: 'Visit History',
          onTap: () => context.push('/visit-history'),
        ),
        const SizedBox(height: 8),
        JourneyMenuTile(
          icon: LucideIcons.mapPin,
          label: 'Exploration Map',
          onTap: () => context.push('/exploration-map'),
        ),
        const SizedBox(height: 8),
        JourneyMenuTile(
          icon: LucideIcons.award,
          label: 'View All Progress',
          onTap: () => context.push('/achievements'),
        ),
      ],
    );
  }
}

class _ProgressToTitle extends StatelessWidget {
  const _ProgressToTitle({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    const target = 300;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress to',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Text(
                      'Makan Sifu',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              Text(
                '$score/$target pts',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / target,
              minHeight: 8,
              backgroundColor: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
