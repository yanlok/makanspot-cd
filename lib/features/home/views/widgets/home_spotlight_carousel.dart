import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/home/models/restaurant_summary.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

class HomeSpotlightCarousel extends StatefulWidget {
  const HomeSpotlightCarousel({
    required this.restaurants,
    required this.onOpen,
    super.key,
  });

  final List<RestaurantSummary> restaurants;
  final ValueChanged<String> onOpen;

  @override
  State<HomeSpotlightCarousel> createState() => _HomeSpotlightCarouselState();
}

class _HomeSpotlightCarouselState extends State<HomeSpotlightCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  List<RestaurantSummary> get _items =>
      widget.restaurants.take(5).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_items.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final next = (_currentPage + 1) % _items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _startTimer();
            },
            itemBuilder: (context, index) {
              final restaurant = _items[index];
              return _SpotlightCard(
                restaurant: restaurant,
                onTap: () => widget.onOpen(restaurant.id),
              );
            },
          ),
        ),
        if (_items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_items.length, (index) {
              final isSelected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.secondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.restaurant,
    required this.onTap,
  });

  final RestaurantSummary restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: AppColors.shadow,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MakanNetworkImage(
                url: restaurant.imageUrl,
                semanticLabel: restaurant.name,
              ),
              // Gradient for readability
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black26,
                      Colors.black87,
                    ],
                    stops: [0.3, 0.6, 1.0],
                  ),
                ),
              ),
              // Top badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 12,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Spotlight',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom content
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            restaurant.cuisine,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
