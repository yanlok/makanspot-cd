import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post_model.dart';
import '../controllers/community_controller.dart';
import '../../../../shared/widgets/async_widget.dart';

class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(communityFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () {})],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(communityFeedProvider.future),
        child: AsyncWidget(
          value: feedAsync,
          builder: (posts) => posts.isEmpty
            ? const Center(child: Text('No posts yet. Be the first to share!'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 24),
                itemBuilder: (context, index) => PostCard(post: posts[index]),
              ),
        ),
      ),
    );
  }
}

class PostCard extends ConsumerWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.secondaryColor,
                backgroundImage: post.userAvatarUrl != null ? NetworkImage(post.userAvatarUrl!) : null,
                child: post.userAvatarUrl == null ? const Icon(Icons.person, size: 20, color: AppTheme.primaryColor) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.username ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (post.restaurantName != null) Text('at ${post.restaurantName}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (post.mediaUrls != null && post.mediaUrls!.isNotEmpty)
          AspectRatio(aspectRatio: 1, child: Image.network(post.mediaUrls!.first, fit: BoxFit.cover)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: post.isLiked ? Colors.red : null),
                    onPressed: () => ref.read(toggleLikePostProvider)(post.id, post.isLiked),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 16),
                  IconButton(icon: const Icon(Icons.send_outlined), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const Spacer(),
                  IconButton(
                    icon: Icon(post.isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: post.isBookmarked ? AppTheme.primaryColor : null),
                    onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${post.likeCount} likes', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (post.content != null)
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(text: '${post.username} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: post.content!),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              if (post.commentCount > 0) Text('View all ${post.commentCount} comments', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 4),
              Text(_formatTime(post.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
