import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class DiscoverFilterStrip extends StatelessWidget {
  const DiscoverFilterStrip({
    required this.options,
    required this.selected,
    required this.onToggle,
    this.stripKey,
    super.key,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final Key? stripKey;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: stripKey,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: options.map((option) {
          final isSelected = selected.contains(option);
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.small),
            child: Semantics(
              selected: isSelected,
              button: true,
              child: Material(
                color: isSelected ? AppColors.primary : AppColors.surface,
                shape: StadiumBorder(
                  side: isSelected
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.secondary),
                ),
                child: InkWell(
                  key: Key('discover-filter-$option'),
                  customBorder: const StadiumBorder(),
                  onTap: () => onToggle(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: 9,
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.surface
                            : AppColors.secondaryForeground,
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
