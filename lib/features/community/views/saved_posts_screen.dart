import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/saved_posts_controller.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_page_header.dart';
import 'widgets/community_post_card.dart';

class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedPostsControllerProvider);
    final controller = ref.read(savedPostsControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Column(
          children: [
            CommunityPageHeader(
              title: 'Saved Posts',
              onBack: context.pop,
              bottom: Text(
                'Posts you bookmarked will appear here.',
                style: Theme.of(context).textTheme.bodySmall,
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
    SavedPostsState state,
    SavedPostsController controller,
  ) {
    if (state.status == SavedPostsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == SavedPostsStatus.error) {
      return CommunityEmptyState(
        icon: LucideIcons.triangleAlert,
        title: 'Could Not Load Saved Posts',
        message: state.errorMessage!,
        actionLabel: 'Try Again',
        onAction: controller.load,
      );
    }
    if (state.status == SavedPostsStatus.empty) {
      return CommunityEmptyState(
        icon: LucideIcons.bookmark,
        title: 'No Saved Posts Yet',
        message:
            'Save reviews in the community feed to quickly find them later.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: _SavedCountCard(count: state.posts.length),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('saved-posts-list'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            itemCount: state.posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final post = state.posts[index];
              return CommunityPostCard(
                post: post,
                onOpen: () => context.push('/post/${post.id}'),
                onRestaurant: () =>
                    context.push('/restaurant/${post.restaurantId}'),
                onLike: () {},
                onSave: () => controller.toggleSave(post.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SavedCountCard extends StatelessWidget {
  const _SavedCountCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              LucideIcons.bookmarkCheck,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              '$count saved ${count == 1 ? 'post' : 'posts'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            Text(
              'Latest first',
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
