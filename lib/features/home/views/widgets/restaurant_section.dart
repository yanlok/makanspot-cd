import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/home/models/restaurant_summary.dart';

import 'restaurant_card.dart';
import 'section_header.dart';

class RestaurantSection extends StatefulWidget {
  const RestaurantSection({
    required this.title,
    required this.restaurants,
    required this.bookmarkedIds,
    required this.onViewAll,
    required this.onBookmark,
    required this.onOpen,
    this.initialCount = 6,
    this.pageSize = 5,
    super.key,
  });

  final String title;
  final List<RestaurantSummary> restaurants;
  final Set<String> bookmarkedIds;
  final VoidCallback onViewAll;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onOpen;
  final int initialCount;
  final int pageSize;

  @override
  State<RestaurantSection> createState() => _RestaurantSectionState();
}

class _RestaurantSectionState extends State<RestaurantSection> {
  late final ScrollController _scrollController;
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.restaurants.isEmpty
        ? 0
        : widget.initialCount.clamp(1, widget.restaurants.length);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant RestaurantSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurants.length != widget.restaurants.length) {
      _visibleCount = widget.restaurants.isEmpty
          ? 0
          : _visibleCount.clamp(1, widget.restaurants.length);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount < widget.restaurants.length) {
      setState(() {
        _visibleCount = (_visibleCount + widget.pageSize)
            .clamp(1, widget.restaurants.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.restaurants.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMore = _visibleCount < widget.restaurants.length;
    final itemCount = hasMore ? _visibleCount + 1 : _visibleCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: SectionHeader(
              title: widget.title,
              onViewAll: widget.onViewAll,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 220,
            child: ListView.separated(
              key: PageStorageKey<String>('section-${widget.title}'),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
              ),
              itemCount: itemCount,
              separatorBuilder: (context, index) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (context, index) {
                if (index == _visibleCount && hasMore) {
                  // End loading / reveal trigger card
                  Future.microtask(_loadMore);
                  return Container(
                    width: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final restaurant = widget.restaurants[index];
                return RestaurantCard(
                  restaurant: restaurant,
                  isBookmarked: widget.bookmarkedIds.contains(restaurant.id),
                  onBookmark: () => widget.onBookmark(restaurant.id),
                  onOpen: () => widget.onOpen(restaurant.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
