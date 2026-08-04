import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../../models/community_models.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    required this.post,
    required this.onOpen,
    required this.onRestaurant,
    required this.onLike,
    this.onReport,
    super.key,
  });

  final CommunityPost post;
  final VoidCallback onOpen;
  final VoidCallback onRestaurant;
  final VoidCallback onLike;
  final VoidCallback? onReport;

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
                          ? Image.asset(
                              'assets/images/default_icon.jpg',
                              fit: BoxFit.cover,
                            )
                          : MakanNetworkImage(
                              url: post.userAvatar,
                              semanticLabel: post.username,
                              fallbackKey: Key('avatar-fallback-${post.id}'),
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
                  if (onReport != null)
                    IconButton(
                      key: Key('report-${post.id}'),
                      tooltip: 'Report content',
                      onPressed: onReport,
                      icon: const Icon(
                        LucideIcons.ellipsis,
                        color: AppColors.mutedForeground,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              key: Key('post-restaurant-${post.id}'),
              onPressed: onRestaurant,
              icon: const Icon(LucideIcons.utensils, size: 16),
              label: Text(post.restaurantName),
            ),
            if (post.rating > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    for (var star = 1; star <= 5; star++)
                      Icon(
                        LucideIcons.star,
                        size: 16,
                        color: star <= post.rating
                            ? const Color(0xFFF5A623)
                            : AppColors.secondary,
                        fill: star <= post.rating ? 1 : 0,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.rating}.0',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            InkWell(
              key: Key('open-post-${post.id}'),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  post.reviewText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
            if (post.mediaUrls.isNotEmpty)
              InkWell(
                onTap: onOpen,
                child: SizedBox(
                  height: 224,
                  width: double.infinity,
                  child: _isVideo(post.mediaUrls.first)
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: AppColors.foreground),
                            const Center(
                              child: Icon(
                                LucideIcons.play,
                                size: 44,
                                color: AppColors.surface,
                              ),
                            ),
                          ],
                        )
                      : MakanNetworkImage(
                          url: post.mediaUrls.first,
                          semanticLabel:
                              'Review photo for ${post.restaurantName}',
                          fallbackKey: Key('post-image-fallback-${post.id}'),
                        ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    key: Key('like-post-${post.id}'),
                    onPressed: onLike,
                    icon: Icon(
                      LucideIcons.heart,
                      size: 20,
                      color: post.isLiked
                          ? AppColors.destructive
                          : AppColors.mutedForeground,
                    ),
                    label: Text(
                      '${post.likes}',
                      style: TextStyle(
                        color: post.isLiked
                            ? AppColors.destructive
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(
                      LucideIcons.messageCircle,
                      size: 20,
                      color: AppColors.mutedForeground,
                    ),
                    label: const Text(''),
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

bool _isVideo(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.webm');
}
