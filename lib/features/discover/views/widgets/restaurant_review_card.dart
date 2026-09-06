import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../../models/discover_restaurant.dart';

class RestaurantReviewCard extends StatelessWidget {
  const RestaurantReviewCard({
    required this.review,
    required this.onLike,
    required this.onOpen,
    super.key,
  });

  final RestaurantReview review;
  final VoidCallback onLike;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      clipBehavior: Clip.antiAlias,
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
                    child: MakanNetworkImage(
                      url: review.avatarUrl,
                      semanticLabel: review.username,
                      fallbackKey: Key('review-avatar-${review.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.username,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        review.profileTitle,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.ellipsis, size: 20),
                  tooltip: 'Review options',
                ),
              ],
            ),
          ),
          InkWell(
            key: Key('review-open-${review.id}'),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                review.reviewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ),
          SizedBox(
            height: 224,
            width: double.infinity,
            child: MakanNetworkImage(
              url: review.imageUrl,
              semanticLabel: 'Review photo by ${review.username}',
              fallbackKey: Key('review-image-${review.id}'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  key: Key('review-like-${review.id}'),
                  onPressed: onLike,
                  icon: Icon(
                    review.isLiked ? Icons.favorite : LucideIcons.heart,
                    size: 20,
                    color: review.isLiked
                        ? AppColors.destructive
                        : AppColors.mutedForeground,
                  ),
                  label: Text(
                    '${review.likes}',
                    style: TextStyle(
                      color: review.isLiked
                          ? AppColors.destructive
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(LucideIcons.messageCircle, size: 20),
                  tooltip: 'Open comments',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
