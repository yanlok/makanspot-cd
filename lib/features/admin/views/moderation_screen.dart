import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/moderation_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_filter_dropdown.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_segmented_tabs.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';

class ContentModerationScreen extends ConsumerStatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  ConsumerState<ContentModerationScreen> createState() =>
      _ContentModerationScreenState();
}

class _ContentModerationScreenState
    extends ConsumerState<ContentModerationScreen> {
  @override
  Widget build(BuildContext context) {
    // ?tab=comment links (e.g. after dismissing a comment) open directly
    // on the comment tab, without first rendering the posts tab.
    final requestedTab =
        GoRouterState.of(context).uri.queryParameters['tab'] ==
            ReportTab.comment.name
        ? ReportTab.comment
        : ReportTab.post;
    final state = ref.watch(moderationControllerProvider(requestedTab));
    final controller = ref.read(
      moderationControllerProvider(requestedTab).notifier,
    );
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          key: const Key('moderation-scroll'),
          // Keep the list scrollable when it is empty so pull-to-refresh
          // still works on the empty and error states.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const AdminPageHeader(
              title: 'Content Moderation',
              subtitle: 'Review reported posts and comments',
            ),
            const SizedBox(height: 20),
            AdminFilterDropdown<ReportFilter>(
              value: state.filter,
              options: const [
                ('All', ReportFilter.all),
                ('Pending', ReportFilter.pending),
                ('Removed', ReportFilter.removed),
              ],
              onChanged: controller.selectFilter,
            ),
            const SizedBox(height: 16),
            AdminSegmentedTabs<ReportTab>(
              value: state.tab,
              tabs: const [
                ('Reported Posts', ReportTab.post),
                ('Reported Comments', ReportTab.comment),
              ],
              onChanged: controller.selectTab,
            ),
            const SizedBox(height: 16),
            if (state.status == ModerationStatus.error)
              _ModerationError(onRetry: controller.load)
            else if (state.status == ModerationStatus.loading)
              const AdminListSkeleton(count: 3, cardHeight: 144)
            else
              state.tab == ReportTab.post
                  ? _ReportList(
                      key: const Key('admin-post-reports'),
                      groups: state.filteredPosts,
                      emptyMessage: 'No reported posts found.',
                    )
                  : _ReportList(
                      key: const Key('admin-comment-reports'),
                      groups: state.filteredComments,
                      emptyMessage: 'No reported comments found.',
                    ),
          ],
        ),
      ),
    );
  }
}

class _ModerationError extends StatelessWidget {
  const _ModerationError({required this.onRetry});

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
            const Text('We could not load reports right now.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.groups,
    required this.emptyMessage,
    super.key,
  });

  final List<ReportedContentGroup> groups;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return AdminEmptyState(
        icon: LucideIcons.flag,
        title: 'No Reports',
        message: emptyMessage,
      );
    }
    return Column(
      children: [
        for (final group in groups) ...[
          _ReportCard(group: group),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.group});

  final ReportedContentGroup group;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('admin-report-${group.contentType.name}-${group.contentId}'),
      // The type is part of the URL because post and comment IDs come
      // from separate identity sequences and can share the same number.
      onTap: () => context.go(
        '/admin/moderation/${group.contentId}?type=${group.contentType.name}',
      ),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.contentPreview.isEmpty
                            ? 'Content unavailable'
                            : group.contentPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.contentOwner.isEmpty
                            ? 'By Unknown user'
                            : 'By ${group.contentOwner}',
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
                AdminStatusBadge(
                  label: group.isRemoved ? 'Removed' : 'Pending',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Reason',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.reports.first.reason.isEmpty
                              ? 'Not provided'
                              : group.reports.first.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Reports',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.reportCount}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Review',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.primary,
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
