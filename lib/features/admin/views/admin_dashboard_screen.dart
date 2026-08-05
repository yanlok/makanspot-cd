import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/admin_dashboard_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_skeletons.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final controller = ref.read(adminDashboardControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('admin-dashboard-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const AdminPageHeader(
            title: 'Dashboard',
            subtitle: 'System overview and moderation summary',
          ),
          const SizedBox(height: 24),
          if (state.status == AdminDashboardStatus.error)
            _DashboardError(onRetry: controller.load)
          else
            _DashboardContent(
              data: state.data,
              loading: state.status == AdminDashboardStatus.loading,
            ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.triangleAlert,
              size: 44,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            const Text('We could not load the dashboard right now.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.loading});

  final AdminDashboardData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatGrid(data: data, loading: loading),
        const SizedBox(height: 24),
        _RecentModeration(data: data, loading: loading),
      ],
    );
  }
}

class _StatCard {
  const _StatCard(
    this.icon,
    this.label,
    this.path,
    this.background,
    this.foreground,
  );

  final IconData icon;
  final String label;
  final String path;
  final Color background;
  final Color foreground;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.data, required this.loading});

  final AdminDashboardData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cards = <_StatCard>[
      _StatCard(
        LucideIcons.users,
        'Registered Users',
        '/admin/users',
        AppColors.primary.withValues(alpha: 0.1),
        AppColors.primary,
      ),
      _StatCard(
        LucideIcons.utensilsCrossed,
        'Restaurants',
        '/admin/restaurants',
        AppColors.success.withValues(alpha: 0.1),
        AppColors.success,
      ),
      _StatCard(
        LucideIcons.fileText,
        'Community Posts',
        '/admin/users',
        AppColors.accent.withValues(alpha: 0.15),
        AppColors.foreground,
      ),
      _StatCard(
        LucideIcons.messageCircle,
        'Comments',
        '/admin/users',
        AppColors.primary.withValues(alpha: 0.1),
        AppColors.primary,
      ),
      _StatCard(
        LucideIcons.flag,
        'Pending Reports',
        '/admin/moderation',
        AppColors.destructive.withValues(alpha: 0.1),
        AppColors.destructive,
      ),
    ];
    final values = <int>[
      data?.userCount ?? 0,
      data?.restaurantCount ?? 0,
      data?.postCount ?? 0,
      data?.commentCount ?? 0,
      data?.pendingReportCount ?? 0,
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCardTile(
                card: cards[0],
                value: values[0],
                loading: loading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCardTile(
                card: cards[1],
                value: values[1],
                loading: loading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCardTile(
                card: cards[2],
                value: values[2],
                loading: loading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCardTile(
                card: cards[3],
                value: values[3],
                loading: loading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatCardTile(card: cards[4], value: values[4], loading: loading),
      ],
    );
  }
}

class _StatCardTile extends StatelessWidget {
  const _StatCardTile({
    required this.card,
    required this.value,
    required this.loading,
  });

  final _StatCard card;
  final int value;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('admin-stat-${card.label}'),
      onTap: () => context.go(card.path),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        height: 136,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              const AdminSkeletonBox(height: 40, width: 40, radius: 12)
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: card.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, size: 20, color: card.foreground),
              ),
            const SizedBox(height: 12),
            if (loading)
              const AdminSkeletonBox(height: 24, width: 64, radius: 6)
            else
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.foreground,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              card.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentModeration extends StatelessWidget {
  const _RecentModeration({required this.data, required this.loading});

  final AdminDashboardData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  'Recent Moderation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('admin-view-all-reports'),
                onPressed: () => context.go('/admin/moderation'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            const AdminListSkeleton(count: 3, cardHeight: 64)
          else if (data!.recentReports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No pending reports. All clear!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else
            for (final group in data!.recentReports) ...[
              _RecentReportRow(group: group),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _RecentReportRow extends StatelessWidget {
  const _RecentReportRow({required this.group});

  final ReportedContentGroup group;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('admin-recent-report-${group.contentId}'),
      onTap: () => context.go('/admin/moderation/${group.contentId}'),
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.flag,
                size: 20,
                color: AppColors.destructive,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (group.contentType == ReportContentType.post
                            ? 'Reported Post'
                            : 'Reported Comment') +
                        (group.contentOwner.isEmpty
                            ? ''
                            : ' · ${group.contentOwner}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    group.reports.first.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
