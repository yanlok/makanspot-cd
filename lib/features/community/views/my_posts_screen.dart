import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/my_posts_controller.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_page_header.dart';
import 'widgets/community_post_card.dart';

class MyPostsScreen extends ConsumerWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myPostsControllerProvider);
    final controller = ref.read(myPostsControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          CommunityPageHeader(
            title: 'My Posts',
            onBack: context.pop,
            bottom: Text(
              'Edit your reviews and move finished ones out of the feed.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          Expanded(child: _buildBody(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MyPostsState state,
    MyPostsController controller,
  ) {
    if (state.status == MyPostsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == MyPostsStatus.error) {
      return CommunityEmptyState(
        icon: LucideIcons.triangleAlert,
        title: 'Could Not Load Posts',
        message: state.errorMessage!,
        actionLabel: 'Try Again',
        onAction: controller.load,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _PostTabs(state: state, controller: controller),
          const SizedBox(height: 16),
          Expanded(
            child: state.visiblePosts.isEmpty
                ? CommunityEmptyState(
                    icon: LucideIcons.fileText,
                    title: state.showArchived
                        ? 'No Archived Posts'
                        : 'No Active Posts',
                    message: state.showArchived
                        ? 'Archived posts will appear here.'
                        : 'Start sharing your food experiences with the community!',
                    actionLabel: state.showArchived ? null : 'Write Review',
                    onAction: state.showArchived
                        ? null
                        : () => context.push('/review/create'),
                  )
                : ListView.separated(
                    key: const Key('my-posts-list'),
                    itemCount: state.visiblePosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final post = state.visiblePosts[index];
                      return Column(
                        children: [
                          CommunityPostCard(
                            post: post,
                            onOpen: () => context.push('/post/${post.id}'),
                            onRestaurant: () => context.push(
                              '/restaurant/${post.restaurantId}',
                            ),
                            onLike: () {},
                            onSave: () => controller.toggleSave(post.id),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: Key('edit-${post.id}'),
                                  onPressed: () =>
                                      context.push('/post/${post.id}/edit'),
                                  icon: const Icon(
                                    LucideIcons.pencil,
                                    size: 16,
                                  ),
                                  label: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: Key(
                                    state.showArchived
                                        ? 'unarchive-${post.id}'
                                        : 'archive-${post.id}',
                                  ),
                                  onPressed: () => state.showArchived
                                      ? controller.unarchive(post.id)
                                      : _confirmArchive(
                                          context,
                                          () => controller.archive(post.id),
                                        ),
                                  icon: Icon(
                                    state.showArchived
                                        ? LucideIcons.archiveRestore
                                        : LucideIcons.archive,
                                    size: 16,
                                  ),
                                  label: Text(
                                    state.showArchived
                                        ? 'Unarchive'
                                        : 'Archive',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Post?'),
        content: const Text(
          'This post will be moved to your archived tab. You can still view it there.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (shouldArchive ?? false) {
      onConfirm();
    }
  }
}

class _PostTabs extends StatelessWidget {
  const _PostTabs({required this.state, required this.controller});

  final MyPostsState state;
  final MyPostsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          _TabButton(
            key: const Key('my-posts-active'),
            selected: !state.showArchived,
            label: 'Active (${state.activeCount})',
            onTap: () => controller.selectArchived(false),
          ),
          _TabButton(
            key: const Key('my-posts-archived'),
            selected: state.showArchived,
            label: 'Archived (${state.archivedCount})',
            onTap: () => controller.selectArchived(true),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.label,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final String label;
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
              color: selected ? AppColors.primary : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
