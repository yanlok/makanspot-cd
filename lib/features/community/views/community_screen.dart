import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/community_controller.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_post_card.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityControllerProvider);
    final controller = ref.read(communityControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _CommunityHeader(
            searchController: _searchController,
            onSearch: controller.updateSearch,
            onMyPosts: () => context.push('/my-posts'),
            onReview: () => context.push('/review/create'),
          ),
          Expanded(child: _buildBody(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CommunityState state,
    CommunityController controller,
  ) {
    switch (state.status) {
      case CommunityStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CommunityStatus.error:
        return CommunityEmptyState(
          icon: LucideIcons.wifiOff,
          title: 'Could Not Load Posts',
          message: state.errorMessage!,
          actionLabel: 'Try Again',
          onAction: controller.load,
        );
      case CommunityStatus.empty:
        return CommunityEmptyState(
          icon: LucideIcons.search,
          title: 'No Posts Yet',
          message:
              'Be the first to share a restaurant review with the community.',
          actionLabel: 'Write Review',
          onAction: () => context.push('/review/create'),
        );
      case CommunityStatus.content:
        return ListView.separated(
          key: const Key('community-post-list'),
          padding: const EdgeInsets.all(16),
          itemCount: state.posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final post = state.posts[index];
            return CommunityPostCard(
              post: post,
              onOpen: () => context.go('/post/${post.id}'),
              onRestaurant: () =>
                  context.push('/restaurant/${post.restaurantId}'),
              onLike: () => controller.toggleLike(post.id),
              onReport: () => _showReportDialog(context),
            );
          },
        );
    }
  }

  void _showReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Content'),
        content: const Text('Thanks. We will review this community post.'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.searchController,
    required this.onSearch,
    required this.onMyPosts,
    required this.onReview,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onMyPosts;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.secondary)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Community',
                          maxLines: 1,
                          softWrap: false,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        'Community reviews & food stories',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('community-my-posts'),
                  onPressed: onMyPosts,
                  child: const Text('My Posts'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('community-write-review'),
                  onPressed: onReview,
                  icon: const Icon(LucideIcons.plus, size: 19),
                  label: const Text('Review'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: TextField(
                key: const Key('community-search'),
                controller: searchController,
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search posts or restaurants',
                  prefixIcon: Icon(LucideIcons.search, size: 19),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
