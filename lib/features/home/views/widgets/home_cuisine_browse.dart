import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class HomeCuisineBrowse extends StatelessWidget {
  const HomeCuisineBrowse({
    required this.onSelectCuisine,
    super.key,
  });

  final ValueChanged<String> onSelectCuisine;

  static const _cuisines = <(String, String)>[
    ('Street Food', '🍜'),
    ('Cafe', '☕'),
    ('Malay', '🍛'),
    ('Chinese', '🥢'),
    ('Mamak', '🫓'),
    ('Dessert & Bakery', '🍰'),
    ('Western', '🥩'),
    ('Japanese', '🍣'),
    ('Seafood', '🦐'),
    ('Vegetarian', '🥗'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Craving Something?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Browse your favorite food categories',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _cuisines.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final (name, emoji) = _cuisines[index];
              return _CuisineItem(
                name: name,
                emoji: emoji,
                onTap: () => onSelectCuisine(name),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CuisineItem extends StatelessWidget {
  const _CuisineItem({
    required this.name,
    required this.emoji,
    required this.onTap,
  });

  final String name;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondary),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
