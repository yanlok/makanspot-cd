import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/community_controller.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_post_card.dart';
import 'widgets/community_report_dialog.dart';

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
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: _CommunityDrawer(
          onMyPosts: () => context.push('/my-posts'),
          onSavedPosts: () => context.push('/saved-posts'),
        ),
        floatingActionButton: PopupMenuButton<String>(
          key: const Key('community-write-review'),
          tooltip: 'Add review',
          position: PopupMenuPosition.over,
          offset: const Offset(0, -8),
          onSelected: (_) => context.push('/review/create'),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'review',
              child: Text('Write a review'),
            ),
          ],
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.plus, color: AppColors.surface),
          ),
        ),
        body: Column(
          children: [
            _CommunityHeader(
              searchController: _searchController,
              onSearch: controller.updateSearch,
            ),
            Expanded(child: _buildBody(context, state, controller)),
          ],
        ),
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
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
              onSave: () => controller.toggleSave(post.id),
              onReport: () => _showReportDialog(context, post.id, controller),
            );
          },
        );
    }
  }

  Future<void> _showReportDialog(
    BuildContext context,
    String postId,
    CommunityController controller,
  ) async {
    final submission = await showCommunityReportDialog(
      context,
      contentLabel: 'post',
    );
    if (submission != null && context.mounted) {
      await controller.reportPost(
        postId,
        submission.reason,
        details: submission.details,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report sent to moderators.')),
        );
      }
    }
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.searchController,
    required this.onSearch,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: AppColors.secondary)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: TextField(
                  key: const Key('community-search'),
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Find a dish, place, or food story',
                    prefixIcon: Icon(LucideIcons.search, size: 19),
                    suffixIcon: Icon(LucideIcons.slidersHorizontal, size: 18),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                key: const Key('community-menu'),
                tooltip: 'Community menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(LucideIcons.menu, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityDrawer extends StatelessWidget {
  const _CommunityDrawer({required this.onMyPosts, required this.onSavedPosts});

  final VoidCallback onMyPosts;
  final VoidCallback onSavedPosts;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ListTile(
              leading: const Icon(LucideIcons.userRound),
              title: const Text('My Posts'),
              onTap: () {
                Navigator.pop(context);
                onMyPosts();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.bookmark),
              title: const Text('Saved'),
              onTap: () {
                Navigator.pop(context);
                onSavedPosts();
              },
            ),
          ],
        ),
      ),
    );
  }
}
