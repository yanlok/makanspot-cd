import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/journey_controller.dart';
import '../models/journey_models.dart';
import 'widgets/journey_widgets.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

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
    final data = state.data!;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _AchievementsHero(data: data, onBack: context.pop),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _AchievementTabs(state: state, controller: controller),
                  const SizedBox(height: 16),
                  Expanded(child: _tabBody(state, data)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBody(JourneyState state, JourneyData data) {
    final progress = data.achievementProgress;
    switch (state.achievementTab) {
      case AchievementTab.earned:
        return _AchievementList(
          key: const Key('earned-achievements'),
          items: progress.where((item) => item.earned).toList(growable: false),
          emptyIcon: LucideIcons.award,
          emptyText: 'No badges earned yet. Keep exploring!',
        );
      case AchievementTab.locked:
        return _AchievementList(
          key: const Key('locked-achievements'),
          items: progress.where((item) => !item.earned).toList(growable: false),
          emptyIcon: LucideIcons.star,
          emptyText: "All badges unlocked! You're a true Makan Legend!",
        );
      case AchievementTab.history:
        return _HistoryList(items: data.scoreHistory);
    }
  }
}

class _AchievementsHero extends StatelessWidget {
  const _AchievementsHero({required this.data, required this.onBack});

  final JourneyData data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const target = 300;
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                color: AppColors.surface,
                icon: const Icon(LucideIcons.chevronLeft),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data.user.profileTitle,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Next: Makan Sifu',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xCCFFF9EF),
                          ),
                        ),
                      ),
                      Text(
                        '${data.user.communityScore}/$target',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xCCFFF9EF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: data.user.communityScore / target,
                      minHeight: 8,
                      backgroundColor: AppColors.surface.withValues(alpha: 0.2),
                      color: AppColors.accent,
                    ),
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

class _AchievementTabs extends StatelessWidget {
  const _AchievementTabs({required this.state, required this.controller});

  final JourneyState state;
  final JourneyController controller;

  @override
  Widget build(BuildContext context) {
    final progress = state.data!.achievementProgress;
    final earned = progress.where((item) => item.earned).length;
    final locked = progress.length - earned;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Earned ($earned)',
            selected: state.achievementTab == AchievementTab.earned,
            onTap: () => controller.selectAchievementTab(AchievementTab.earned),
          ),
          _Tab(
            label: 'Locked ($locked)',
            selected: state.achievementTab == AchievementTab.locked,
            onTap: () => controller.selectAchievementTab(AchievementTab.locked),
          ),
          _Tab(
            label: 'History',
            selected: state.achievementTab == AchievementTab.history,
            onTap: () =>
                controller.selectAchievementTab(AchievementTab.history),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: selected ? AppColors.primary : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementList extends StatelessWidget {
  const _AchievementList({
    required this.items,
    required this.emptyIcon,
    required this.emptyText,
    super.key,
  });

  final List<JourneyAchievementProgress> items;
  final IconData emptyIcon;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 8),
            Text(emptyText, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          AchievementProgressCard(progress: items[index]),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});

  final List<JourneyScoreActivity> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('score-history'),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: AppColors.secondary),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.isReview ? LucideIcons.penLine : LucideIcons.mapPin,
                  size: 17,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.date.day} Jul ${item.date.year}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+${item.points}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.success),
              ),
            ],
          ),
        );
      },
    );
  }
}
