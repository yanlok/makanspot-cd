import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/post_details_controller.dart';
import '../models/community_models.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_page_header.dart';

class PostDetailsScreen extends ConsumerStatefulWidget {
  const PostDetailsScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends ConsumerState<PostDetailsScreen> {
  final _commentController = TextEditingController();
  final _replyController = TextEditingController();
  String? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = postDetailsControllerProvider(widget.postId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          CommunityPageHeader(title: 'Post', onBack: context.pop),
          Expanded(child: _buildBody(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PostDetailsState state,
    PostDetailsController controller,
  ) {
    switch (state.status) {
      case PostDetailsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case PostDetailsStatus.notFound:
        return const CommunityEmptyState(
          icon: LucideIcons.messageCircle,
          title: 'Post Not Found',
          message: 'This post may have been removed.',
        );
      case PostDetailsStatus.error:
        return CommunityEmptyState(
          icon: LucideIcons.triangleAlert,
          title: 'Could Not Load Post',
          message: state.errorMessage!,
          actionLabel: 'Try Again',
          onAction: controller.load,
        );
      case PostDetailsStatus.content:
        final post = state.post!;
        final topLevel = state.comments
            .where((comment) => comment.parentCommentId == null)
            .toList(growable: false);
        return ListView(
          key: const Key('post-details-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            _DetailedPostCard(post: post, controller: controller),
            const SizedBox(height: 16),
            Text(
              'Comments (${state.comments.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _CommentComposer(
              controller: _commentController,
              hint: 'Write a comment...',
              onSend: () async {
                await controller.addComment(_commentController.text);
                _commentController.clear();
              },
            ),
            const SizedBox(height: 16),
            if (topLevel.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No comments yet. Start the conversation!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              )
            else
              for (final comment in topLevel) ...[
                _CommentCard(
                  comment: comment,
                  isReplying: _replyingTo == comment.id,
                  onReply: () {
                    setState(() {
                      _replyingTo = _replyingTo == comment.id
                          ? null
                          : comment.id;
                      _replyController.clear();
                    });
                  },
                ),
                if (_replyingTo == comment.id)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 8, 0, 8),
                    child: _CommentComposer(
                      controller: _replyController,
                      hint: 'Reply to ${comment.username}...',
                      onSend: () async {
                        await controller.addComment(
                          _replyController.text,
                          parentCommentId: comment.id,
                        );
                        _replyController.clear();
                        setState(() => _replyingTo = null);
                      },
                    ),
                  ),
                for (final reply in state.comments.where(
                  (item) => item.parentCommentId == comment.id,
                ))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 4, 0, 8),
                    child: _CommentCard(comment: reply, isReply: true),
                  ),
                const SizedBox(height: 8),
              ],
          ],
        );
    }
  }
}

class _DetailedPostCard extends StatelessWidget {
  const _DetailedPostCard({required this.post, required this.controller});

  final CommunityPost post;
  final PostDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 40,
                      child: post.userAvatar.isEmpty
                          ? Image.asset('assets/images/default_icon.jpg')
                          : MakanNetworkImage(
                              url: post.userAvatar,
                              semanticLabel: post.username,
                              fallbackKey: const Key('details-avatar-fallback'),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          post.profileTitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Report post',
                    onPressed: () {},
                    icon: const Icon(LucideIcons.ellipsis, size: 20),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/restaurant/${post.restaurantId}'),
              icon: const Icon(LucideIcons.utensils, size: 16),
              label: Text(post.restaurantName),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                post.reviewText,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
            if (post.mediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: MakanNetworkImage(
                      url: post.mediaUrls.first,
                      semanticLabel: 'Review photo',
                      fallbackKey: const Key('details-image-fallback'),
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextButton.icon(
                key: const Key('details-like'),
                onPressed: controller.toggleLike,
                icon: Icon(
                  LucideIcons.heart,
                  size: 20,
                  color: post.isLiked
                      ? AppColors.destructive
                      : AppColors.mutedForeground,
                ),
                label: Text('${post.likes}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/default_icon.jpg',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send',
          onPressed: onSend,
          icon: const Icon(LucideIcons.send, size: 17),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    this.isReplying = false,
    this.isReply = false,
    this.onReply,
  });

  final CommunityComment comment;
  final bool isReplying;
  final bool isReply;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isReply)
          const Padding(
            padding: EdgeInsets.only(right: 6, top: 8),
            child: Icon(
              LucideIcons.cornerDownRight,
              size: 16,
              color: AppColors.mutedForeground,
            ),
          ),
        ClipOval(
          child: Image.asset(
            'assets/images/default_icon.jpg',
            width: isReply ? 28 : 32,
            height: isReply ? 28 : 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.username,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(comment.text),
                  ],
                ),
              ),
              if (!isReply)
                TextButton(
                  onPressed: onReply,
                  child: Text(isReplying ? 'Cancel' : 'Reply'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
