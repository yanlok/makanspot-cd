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
          _JourneyHero(data: state.data!),
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
  const _JourneyHero({required this.data});

  final JourneyData data;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journey',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.surface),
            ),
            const SizedBox(height: 16),
            Container(
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

class _JourneyContent extends StatefulWidget {
  const _JourneyContent({required this.data});

  final JourneyData data;

  @override
  State<_JourneyContent> createState() => _JourneyContentState();
}

class _JourneyContentState extends State<_JourneyContent> {
  JourneyVisitPeriod _period = JourneyVisitPeriod.allTime;

  List<JourneyVisit> _filteredVisits(JourneyData data) {
    final now = DateTime.now();
    DateTime? from;
    switch (_period) {
      case JourneyVisitPeriod.allTime:
        from = null;
        break;
      case JourneyVisitPeriod.last30Days:
        from = now.subtract(const Duration(days: 30));
        break;
      case JourneyVisitPeriod.last12Months:
        from = DateTime(now.year - 1, now.month, now.day);
        break;
      case JourneyVisitPeriod.yearToDate:
        from = DateTime(now.year, 1, 1);
        break;
    }
    if (from == null) return data.visits;
    return data.visits
        .where((v) => v.visitDate.isAfter(from!))
        .toList(growable: false);
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final earned = data.achievementProgress
        .where((item) => item.earned)
        .take(3)
        .toList(growable: false);
    final visits = _filteredVisits(data);
    final uniqueRestaurants = visits.map((v) => v.restaurantId).toSet().length;
    final reviews = visits.where((v) => v.postId != null).length;
    final cuisines = visits
        .map((v) => v.cuisine)
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exploration Overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            PopupMenuButton<JourneyVisitPeriod>(
              initialValue: _period,
              onSelected: (p) => setState(() => _period = p),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: JourneyVisitPeriod.allTime,
                  child: Text('All time'),
                ),
                const PopupMenuItem(
                  value: JourneyVisitPeriod.last30Days,
                  child: Text('Last 30 days'),
                ),
                const PopupMenuItem(
                  value: JourneyVisitPeriod.last12Months,
                  child: Text('Last 12 months'),
                ),
                const PopupMenuItem(
                  value: JourneyVisitPeriod.yearToDate,
                  child: Text('Year to date'),
                ),
              ],
              child: Row(
                children: [
                  Text(
                    _period == JourneyVisitPeriod.allTime
                        ? 'All time'
                        : _period == JourneyVisitPeriod.last30Days
                        ? '30 days'
                        : _period == JourneyVisitPeriod.last12Months
                        ? '12 months'
                        : 'YTD',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.chevronDown, size: 16),
                ],
              ),
            ),
          ],
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
              value: uniqueRestaurants,
              label: 'Restaurants Visited',
            ),
            JourneyStatCard(
              icon: LucideIcons.penLine,
              value: reviews,
              label: 'Reviews Submitted',
            ),
            JourneyStatCard(
              icon: LucideIcons.compass,
              value: cuisines,
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
        Text(
          'Recent Activities',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final visit in visits.take(6)) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.secondary),
            ),
            child: Row(
              children: [
                if (visit.restaurantImage.isNotEmpty)
                  Image.network(
                    visit.restaurantImage,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                else
                  Container(width: 56, height: 56, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.restaurantName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${visit.cuisine} • ${_formatDate(visit.visitDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: visit.postId != null
                      ? () => context.push('/post/${visit.postId}')
                      : null,
                  icon: const Icon(LucideIcons.chevronRight),
                ),
              ],
            ),
          ),
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
