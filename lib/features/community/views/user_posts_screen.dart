import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/user_posts_controller.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_page_header.dart';
import 'widgets/community_post_card.dart';

class UserPostsScreen extends ConsumerWidget {
  const UserPostsScreen({
    required this.userId,
    required this.username,
    super.key,
  });

  final String userId;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userPostsControllerProvider(userId));
    final controller = ref.read(userPostsControllerProvider(userId).notifier);

    return SafeArea(
      bottom: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Column(
          children: [
            CommunityPageHeader(
              title: 'Posts by $username',
              onBack: context.pop,
              bottom: Text(
                'Community reviews shared by $username.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            Expanded(child: _buildBody(context, state, controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    UserPostsState state,
    UserPostsController controller,
  ) {
    switch (state.status) {
      case UserPostsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case UserPostsStatus.error:
        return CommunityEmptyState(
          icon: LucideIcons.triangleAlert,
          title: 'Could Not Load Posts',
          message: state.errorMessage!,
          actionLabel: 'Try Again',
          onAction: controller.load,
        );
      case UserPostsStatus.content:
        if (state.posts.isEmpty) {
          return CommunityEmptyState(
            icon: LucideIcons.fileText,
            title: 'No Posts Yet',
            message: '$username has not shared any community reviews yet.',
          );
        }
        return ListView.separated(
          key: Key('user-posts-list-$userId'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: state.posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final post = state.posts[index];
            return CommunityPostCard(
              post: post,
              onOpen: () => context.push('/post/${post.id}'),
              onRestaurant: () =>
                  context.push('/restaurant/${post.restaurantId}'),
              onLike: () => controller.toggleLike(post.id),
              onSave: () => controller.toggleSave(post.id),
            );
          },
        );
    }
  }
}
