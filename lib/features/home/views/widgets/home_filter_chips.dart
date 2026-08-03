import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class HomeFilterChips extends StatelessWidget {
  const HomeFilterChips({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  static const filters = <String>[
    'Near Me',
    'Budget',
    'Open Now',
    'Mamak',
    'Street Food',
    'Desserts',
    'Hidden Gems',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: AppSpacing.small);
        },
        itemBuilder: (context, index) {
          final filter = filters[index];
          return ActionChip(
            key: Key('home-filter-$filter'),
            onPressed: () => onSelected(filter),
            label: Text(filter),
            labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryForeground,
            ),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.secondary),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }
}
