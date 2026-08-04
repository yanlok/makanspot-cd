import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/review_editor_controller.dart';
import '../models/community_models.dart';
import 'widgets/community_empty_state.dart';
import 'widgets/community_page_header.dart';

class CreateReviewScreen extends StatelessWidget {
  const CreateReviewScreen({this.restaurantId, super.key});

  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    return ReviewEditorScreen(
      arguments: ReviewEditorArguments(restaurantId: restaurantId),
      title: 'Write a Review',
    );
  }
}

class EditPostScreen extends StatelessWidget {
  const EditPostScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return ReviewEditorScreen(
      arguments: ReviewEditorArguments(postId: postId),
      title: 'Edit Post',
    );
  }
}

class ReviewEditorScreen extends ConsumerStatefulWidget {
  const ReviewEditorScreen({
    required this.arguments,
    required this.title,
    super.key,
  });

  final ReviewEditorArguments arguments;
  final String title;

  @override
  ConsumerState<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends ConsumerState<ReviewEditorScreen> {
  final _reviewController = TextEditingController();
  final _restaurantSearchController = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _reviewController.dispose();
    _restaurantSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = reviewEditorControllerProvider(widget.arguments);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (!_seeded && state.status == ReviewEditorStatus.ready) {
      _reviewController.text = state.reviewText;
      _seeded = true;
    }
    ref.listen(provider, (previous, next) {
      if (next.status == ReviewEditorStatus.success &&
          next.savedPostId != null) {
        context.go('/post/${next.savedPostId}');
      }
    });
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          CommunityPageHeader(title: widget.title, onBack: context.pop),
          Expanded(child: _buildBody(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ReviewEditorState state,
    ReviewEditorController controller,
  ) {
    switch (state.status) {
      case ReviewEditorStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ReviewEditorStatus.notFound:
        return const CommunityEmptyState(
          icon: LucideIcons.fileQuestion,
          title: 'Post Not Found',
          message: 'This post may have been removed.',
        );
      case ReviewEditorStatus.error:
        return CommunityEmptyState(
          icon: LucideIcons.triangleAlert,
          title: 'Could Not Open Editor',
          message: state.errorMessage!,
          actionLabel: 'Try Again',
          onAction: controller.load,
        );
      case ReviewEditorStatus.ready:
      case ReviewEditorStatus.submitting:
      case ReviewEditorStatus.success:
        return ListView(
          key: const Key('review-editor-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Restaurant', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (state.selectedRestaurant != null)
              _SelectedRestaurant(
                restaurant: state.selectedRestaurant!,
                canClear: widget.arguments.postId == null,
                onClear: controller.clearRestaurant,
              )
            else
              _RestaurantPicker(
                searchController: _restaurantSearchController,
                restaurants: state.restaurants,
                onSelected: controller.selectRestaurant,
              ),
            const SizedBox(height: 20),
            Text('Your Rating', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            _RatingPicker(
              value: state.rating,
              onChanged: controller.updateRating,
            ),
            const SizedBox(height: 20),
            Text(
              widget.arguments.postId == null ? 'Your Review' : 'Review',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('review-text'),
              controller: _reviewController,
              onChanged: controller.updateReview,
              maxLines: 6,
              minLines: 6,
              decoration: const InputDecoration(
                hintText:
                    'Share your makan experience... How was the food? The '
                    'service? The ambiance?',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Photos & videos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${state.media.length}/5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < state.media.length; index++)
                  _MediaTile(
                    media: state.media[index],
                    index: index,
                    onRemove: () => controller.removeMedia(index),
                  ),
                if (state.media.length < 5)
                  _AddMediaTile(
                    onPhotos: controller.pickImages,
                    onVideo: controller.pickVideo,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: context.pop,
                    style: _buttonStyle(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('submit-review'),
                    onPressed:
                        state.canSubmit &&
                            state.status != ReviewEditorStatus.submitting
                        ? controller.submit
                        : null,
                    style: _buttonStyle(),
                    child: Text(
                      state.status == ReviewEditorStatus.submitting
                          ? 'Saving...'
                          : widget.arguments.postId == null
                          ? 'Post Review'
                          : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  ButtonStyle _buttonStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
  }
}

class _SelectedRestaurant extends StatelessWidget {
  const _SelectedRestaurant({
    required this.restaurant,
    required this.canClear,
    required this.onClear,
  });

  final CommunityRestaurant restaurant;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 48,
                child: MakanNetworkImage(
                  url: restaurant.imageUrl,
                  semanticLabel: restaurant.name,
                  fallbackKey: Key('selected-restaurant-${restaurant.id}'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    restaurant.cuisine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (canClear)
              IconButton(
                tooltip: 'Clear restaurant',
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantPicker extends StatefulWidget {
  const _RestaurantPicker({
    required this.searchController,
    required this.restaurants,
    required this.onSelected,
  });

  final TextEditingController searchController;
  final List<CommunityRestaurant> restaurants;
  final ValueChanged<CommunityRestaurant> onSelected;

  @override
  State<_RestaurantPicker> createState() => _RestaurantPickerState();
}

class _RestaurantPickerState extends State<_RestaurantPicker> {
  @override
  Widget build(BuildContext context) {
    final query = widget.searchController.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? const <CommunityRestaurant>[]
        : widget.restaurants
              .where(
                (item) =>
                    item.name.toLowerCase().contains(query) ||
                    item.cuisine.toLowerCase().contains(query),
              )
              .take(5)
              .toList(growable: false);
    return Column(
      children: [
        if (widget.restaurants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: const Text(
              'No approved restaurants are available yet. Apply the demo '
              'restaurant migration, then tap Try Again.',
              textAlign: TextAlign.center,
            ),
          )
        else
          TextField(
            key: const Key('restaurant-search'),
            controller: widget.searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search for a restaurant...',
              prefixIcon: Icon(LucideIcons.search, size: 19),
            ),
          ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: AppColors.secondary),
            ),
            child: Column(
              children: matches
                  .map(
                    (restaurant) => ListTile(
                      key: Key('restaurant-result-${restaurant.id}'),
                      title: Text(restaurant.name),
                      subtitle: Text(restaurant.cuisine),
                      trailing: const Icon(LucideIcons.utensils, size: 17),
                      onTap: () => widget.onSelected(restaurant),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: value == 0 ? 'No rating selected' : '$value out of 5 stars',
      child: Row(
        children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
              key: Key('review-rating-$star'),
              tooltip: '$star star${star == 1 ? '' : 's'}',
              onPressed: () => onChanged(star),
              icon: Icon(
                star <= value ? LucideIcons.star : LucideIcons.star,
                color: star <= value
                    ? const Color(0xFFF5A623)
                    : AppColors.secondary,
                fill: star <= value ? 1 : 0,
              ),
            ),
          if (value > 0)
            Text('$value.0', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.index,
    required this.onRemove,
  });

  final ReviewMedia media;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: media.type == ReviewMediaType.video
                  ? Container(
                      color: AppColors.foreground,
                      child: const Icon(
                        LucideIcons.play,
                        color: AppColors.surface,
                        size: 30,
                      ),
                    )
                  : media.isLocal
                  ? Image.file(
                      File(media.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        LucideIcons.imageOff,
                        color: AppColors.mutedForeground,
                      ),
                    )
                  : MakanNetworkImage(
                      url: media.path,
                      semanticLabel: 'Review photo ${index + 1}',
                      fallbackKey: Key('editor-photo-$index'),
                    ),
            ),
          ),
          Positioned(
            right: -5,
            top: -5,
            child: IconButton.filled(
              key: Key('remove-photo-$index'),
              tooltip: 'Remove photo',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.destructive,
                minimumSize: const Size.square(24),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(LucideIcons.x, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  const _AddMediaTile({required this.onPhotos, required this.onVideo});

  final VoidCallback onPhotos;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('add-review-photo'),
      onSelected: (value) => value == 'video' ? onVideo() : onPhotos(),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'photos',
          child: ListTile(
            leading: Icon(LucideIcons.images),
            title: Text('Choose photos'),
          ),
        ),
        PopupMenuItem(
          value: 'video',
          child: ListTile(
            leading: Icon(LucideIcons.video),
            title: Text('Choose video'),
          ),
        ),
      ],
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: AppColors.secondary,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, color: AppColors.mutedForeground),
            SizedBox(height: 4),
            Text(
              'Add media',
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
